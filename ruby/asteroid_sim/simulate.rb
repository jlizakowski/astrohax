#!/usr/bin/env ruby

require 'pp'
require 'date'
require 'pry'

require_relative './sim_physics'
require_relative './sim_helpers'
require_relative './sim_propagate'
require_relative './sim_particles'

require_relative './constants'
require_relative './orbital_state'
require_relative '../horizons/horizons'
require_relative '../horizons/tle_to_opm'


def find_stats(arr) #TODO
  puts "statistics of the semimajor axis and eccentricity, including the average, mean, and standard deviation."
  puts avg, mean, stddev
end

# Generic iteration function
def iterate(val, func, duration, steps)
  steps.to_i.times do
    val = func.call(val, duration / steps)
    status.print_status_dots
  end
  val
end

def load_large_bodies(epoch)
  bodies = [
      lookup_opm(399, epoch), # Earth
      lookup_opm(301, epoch), # Earth's Moon
      lookup_opm(10, epoch) # Sun
  ]
  bodies
end

def puts_particle_energy(particles)
  particles.each do |part|
    puts "#{part.state.pos_m}, \t#{total_energy_j(part.state)}"
  end
end

def print_summary(new_state, opts, initial_state)

  puts "initial_state = \t#{initial_state.pretty_inspect}"
  puts "ending_state = \t#{new_state.pretty_inspect}"

  puts "opts: #{opts.pretty_inspect}"

  semi_minor_axis = Math.sqrt((1 - new_state.eccentricity ** 2) * new_state.semi_major_axis ** 2)

  puts "avg Energy error vs avg start: \t#{(new_state.initial_energy_j - new_state.running_avg_energy_j) / new_state.initial_energy_j}"
  puts "avg Energy error vs orig start: \t#{(initial_state.initial_energy_j - new_state.running_avg_energy_j) / initial_state.initial_energy_j}"
  puts "diff orig vs final start energies: \t#{(initial_state.initial_energy_j - new_state.initial_energy_j) / initial_state.initial_energy_j}"
  
  puts "Given semi_major_axis: #{initial_state.semi_major_axis},\t eccentricity: #{initial_state.eccentricity}"
  puts "Calc  semi_major_axis: #{new_state.semi_major_axis},\t eccentricity: #{new_state.eccentricity}"
  # puts "Calculated semi_major_axis: #{new_state.sim_max_dist},\t eccentricity: #{Math.sqrt(new_state.sim_max_dist ** 2 - new_state.sim_min_dist ** 2) / new_state.sim_max_dist}"
  #minor = major * sqrt(1-e**2)

  puts "record log10 of smallest/largest steps in each value (metamagic class for this?)"
  puts "then be a web service"
end

def make_filename_prefix(opts)
  git_commit_number = `git log --pretty=oneline | wc -l`.strip
  fn_prefix         = "#{opts[:epoch].gsub(/[^a-zA-Z0-9\-_.]/, '_')}_gitver#{git_commit_number.to_i}_p#{opts[:n_particles].to_i}_yrs#{(opts[:total_duration_s] / 3600.0 / 24 / 365).to_i}_steps#{opts[:steps].to_i}_skip#{opts[:skip_factor].to_i}"
end

def print_starting_summary(initial_state, opts, particles)
  puts "Running with settings #{opts}"
  puts "Initial state:\n #{initial_state.pretty_inspect}"
  puts_particle_energy(particles)
end


def run(opts)
  pp opts
  defaults = {}
  opts     = defaults.merge(opts)
  opts[:epoch] = DateTime.parse(opts[:epoch]).strftime('%F %T')  #cleanup format

  fn_prefix = make_filename_prefix(opts)
  #don't use a power of ten exactly, prime is better to reduce artifacts between float precision and powers of 10
  skip_factor = nonprime_near(opts[:skip_factor])
  `mkdir -p results/#{fn_prefix};  touch results/#{fn_prefix}` #touch the directory to update timestamp

  status = StatusPrinter.new(Math.log10(skip_factor).round.to_i)

  initial_state = lookup_opm(opts[:query], opts[:epoch])
  large_bodies = load_large_bodies(opts[:epoch])

  generate_graphviz_force_diagram(large_bodies << initial_state, fn_prefix)

  particles = ParticleTools.expand_pdf(initial_state, opts[:n_particles], fn_prefix)
  particles.map { |p| p.record_start_state }

  print_starting_summary(initial_state, opts, particles)

  step_duration_s    = opts[:total_duration_s] / opts[:steps]
  num_printing_iters = (opts[:steps] / opts[:skip_factor]).round.to_i

  start_time_s = Time.now.to_f
  num_printing_iters.times do |printing_iter|
    loop_time_s = Time.now.to_f
    opts[:skip_factor].to_i.times do |step_n|
      large_bodies_next = propagateNBody(large_bodies, step_duration_s) #iterate these separately, more efficient across particles
      particles.map! { |particle|
        particle.state = propagatePartialNBody(large_bodies, large_bodies_next, [particle.state], step_duration_s).first
        particle
      }
      large_bodies = large_bodies_next
    end
    particles.each { |p| p.record_state }
    status.print_status_dots

    delta_sim_s = Time.now.to_f - start_time_s
    avg_loop_s  = delta_sim_s / (printing_iter + 1)
    puts "Completion estimate: #{Time.at(start_time_s + num_printing_iters * avg_loop_s)}"
  end

  #  pp [particle, large_bodies].flatten

  particles.map { |p| p.record_end_state }
  new_state = ParticleTools.collapse_pdf(particles)

  puts "Large Bodies"
  large_bodies.each { |body| pp body }
  puts
  print_summary(new_state, opts, initial_state)
  puts "Particle vels"
  particles.each { |p| pp p.state.vel_mps }

  puts
  avg = particles.reduce(Vector[0, 0, 0]) { |sum, p| p.state.vel_mps + sum } / particles.count.to_f
  pp avg
  pp particles.reduce(Vector[0, 0, 0]) { |sum, p| (p.state.vel_mps + sum - avg) } / particles.count.to_f

  new_state
end


if ARGV.count != 6
  end_state = run(n_particles:      3, steps: 1e4,
                  :total_duration_s => 60 * 60 * 24 * 4, skip_factor: 1e3,
                  :query            => 'apophis', :epoch => '2008-01-01 00:00')
else
  # TODO: make cmd line tool more helpful / optparsing / etc
  query      = ARGV[0]
  start      = ARGV[1]
  stop       = ARGV[2]
  steps      = ARGV[3].to_f.to_i #to get sci notation
  n          = ARGV[4].to_f.to_i
  skip       = ARGV[5].to_f.to_i
  
  start_date = DateTime.parse(start)
  stop_date  = DateTime.parse(stop)
  duration_s = stop_date.to_time - start_date.to_time
  end_state  = run(n_particles:      n, steps: steps,
                   :total_duration_s => duration_s, skip_factor: skip,
                   :query            => query, :epoch => start)
end

puts "done"




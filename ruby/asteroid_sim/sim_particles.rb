require_relative 'orbital_state'
require 'pp'

# Wrap an ObitalState with I/O and helpers
class Particle
  attr_accessor :obj_name, :state, :iter_count
  attr_reader :temp_file_name
  attr :lines, :fn_prefix

  def initialize(state, number, fn_prefix)
    @name       = number.to_s
    @state      = state
    @iter_count = 0
    @fn_prefix  = fn_prefix
    @last_write = Time.now.to_f

    @lines = []

    @temp_file_name = "results/#{fn_prefix}/#{fn_prefix}_particle#{number}.m"
  end


  def record_state
    @lines << " #{[state.epoch.to_f] + state.pos_m.to_a + state.vel_mps.to_a + [potential_energy_j(state),
                                                                                kinetic_energy_j(state), total_energy_j(state), state.running_avg_energy_j]};"
    if @lines.count > 100 or (Time.now.to_f - @last_write) > 60 #buffer the writes, so they are 1% of the time, or every minute
      write
    end
  end

  def record_start_state
    @lines << "#for octave input"
    @lines << "#fields: epoch.to_f, pos_m[], vel_mps[], potential_energy_j, kinetic_energy_j, total_energy_j, running_avg_energy_j"
    @lines << "posvel = ["
  end

  def record_end_state
    write
    @lines << "];"
    @lines << "hold on"
    @lines << "grid on"
    @lines << "scatter(posvel(:,2),posvel(:,3),0.01,#{@name.to_i})"
    @lines << "rotate3d on"
    @lines << "print('./results/#{@fn_prefix}/figure_particle#{@name.to_i}.pdf','-S3000,2400'); "
    write
  end

  def write
    f = File.open(@temp_file_name, 'a')
    f.write(@lines.map { |line| line + "\n" }.join)
    f.close
    @lines      = []
    @last_write = Time.now.to_f
  end

end

# For dealing with collections of Particles
class ParticleTools

  def self.expand_pdf(state, qty, fn_prefix)

    return qty.to_i.times.map do |n|
      s = state.create_particle
      Particle.new(s, n, fn_prefix)
    end

  end

  def self.k_means_pdf(k, arr)
    #split particles[] into k clusters. Helps create a few super-particles, to carry more state and non-gaussian PDFs

    return arr_of_size_k
  end

  def self.collapse_pdf(particles)
    #combine pos and vel into a 6x1 vector
    # make array of row cols for
    #  GSL::Stats::covariance(a,b)
    puts "collapsing pdf"
    state = OrbitalState.new

    pstates = particles.map { |particle| particle.state } #to adapt to new hierarchy

    vecs = [:pos_m, :vel_mps]
    vecs.each { |vec| state.send("#{vec.to_s}=", avg_vectors(pstates, vec)) }

    floats = [:mass_kg, :gm_m3ps2, :semi_major_axis, :eccentricity, :initial_energy_j, :running_avg_energy_j]
    floats.each { |f| state.send("#{f.to_s}=", avg_floats(pstates, f)) }

    state.sim_min_dist = pstates.map { |p| p.sim_min_dist }.min
    state.sim_max_dist = pstates.map { |p| p.sim_max_dist }.max
    state.epoch        = Time.at(pstates.map { |p| p.epoch.to_time.to_f }.max)
    state.covar        = self.covar(pstates)

    puts "avg state= #{state.pretty_inspect}"
    state.semi_major_axis = (state.sim_max_dist + state.sim_min_dist) / 2.0
    # state.eccentricity= Math.sqrt(state.sim_max_dist**2 - state.sim_min_dist**2)/ state.sim_max_dist
    state.eccentricity = (state.sim_max_dist - state.sim_min_dist) / (state.sim_max_dist + state.sim_min_dist)
    puts "ecc= #{state.eccentricity}"

    puts "avg pos_m #{state.pos_m}"
    puts "avg vel_mps #{state.vel_mps}"

    state
  end

  # find the covariance matrix of a collection of particles
  def self.covar(pstates)
    np              = pstates.count
    cov             = GSL::Matrix.alloc(6, 6)
    particle_matrix = GSL::Matrix.send('[]', pstates.map { |p| p.pos_m.to_a.concat(p.vel_mps.to_a) }.flatten, 6, pstates.count)

    #TODO verify this works!
    pp particle_matrix
    (0..5).each do |i|
      (0..5).each do |j|
        a = particle_matrix.row(i)
        b = particle_matrix.row(j)
        c = GSL::Stats::covariance(a, b)
        puts "#{i} #{j} #{a} \t#{b} \t#{c}"
        cov.set(i, j, c)
      end
    end
    cov
  end

end
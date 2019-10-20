require 'matrix'
require 'pp'
require 'date'
require 'gsl'
require './sim_physics'

require './circular_high_low_finder'
require './constants'

class OrbitalState
  #given
  attr_accessor :pos_m, :vel_mps, :covar #3x3, 3x3, 6x6
  attr_accessor :epoch, :mass_kg, :gm_m3ps2, :semi_major_axis, :eccentricity, :radius_m
  attr_accessor :opm_hash, :obj_name

  #determined
  attr_accessor :initial_energy_j
  attr_accessor :sim_max_dist, :sim_min_dist #periapsis and apoapsis
  attr_accessor :high_low_finder
  attr_accessor :running_avg_energy_j
  attr_accessor :closest_to_earth_m

  def initialize(opts = {})
    setup_rnd
    opts.each { |k, v| self.instance_variable_set("@#{k}", v) }
    @high_low_finder    = CircularHighLowFinder.new
    @closest_to_earth_m = Float::MAX
  end

  # create an orbital state with covariances applied randomly to pos and vel
  def create_particle
    particle          = self.clone()
    particle.opm_hash = nil

    #gaussian assumptions are inherent in covariance
    l, u, p = GSL::Linalg::LU.decomp(GSL::Matrix.alloc(particle.covar.to_a.flatten, 6, 6))

    normal_noise = Matrix.build(1, 6) do |row, col|
      $rng.gaussian()   #default variance 1.0, mean 0.0
    end

    l = Matrix.rows(l.to_a) #GSL to Matrix
    delta = normal_noise * l

    particle.pos_m                += Vector.elements(delta.to_a.flatten[0, 3])
    particle.vel_mps              += Vector.elements(delta.to_a.flatten[3, 6])
    particle.initial_energy_j     = total_energy_j(particle)
    particle.running_avg_energy_j = particle.initial_energy_j
    particle.sim_min_dist         = Float::INFINITY
    particle.sim_max_dist         = 0.0
    particle.high_low_finder      = CircularHighLowFinder.new
    particle.obj_name             = "#{self.obj_name}_particle"

    return particle
  end

  def self.load_opm(filename)
    opm_values = self.opm_to_hash(filename)
    state      = self.hash_to_state(opm_values)
  end

  def self.opm_to_hash(filename)
    #groups    (name of variable)   = (numeric/text value) (optional units)
    regexp = /^(?<name>[a-zA-Z_]*) *= *(?<val>[^\[]*) *(?<units>.*)?/

    lines          = File.read(filename).lines.map { |line| line.strip }
    list_of_hashes = lines.map { |line| line.match(regexp)&.named_captures }.compact
    hash           = list_of_hashes.reduce({}) { |accum, item| name = item.delete('name'); accum[name] = item; accum }
    hash
  end

  def self.hash_to_state(opm_vals)
    state      = OrbitalState.new
    dimensions = %w{X Y Z}
    cov_names  = dimensions + dimensions.map { |d| d + "_DOT" }

    # binding.pry
    state.pos_m   = Vector.elements(dimensions.map { |dim| opm_vals[dim] ? opm_vals[dim]['val'].to_f : 0.0 })
    state.vel_mps = Vector.elements(dimensions.map { |dim| opm_vals[dim + '_DOT']['val'].to_f })

    state.pos_m   *= 1000.0 #km to m     #TODO: ensure units are km
    state.vel_mps *= 1000.0 #km to m

    state.covar = Matrix.build(6, 6) do |row, col|
      name = "C#{cov_names[row]}_#{cov_names[col]}"
      opm_vals[name]&.dig('val').to_f
    end

    #Yarkovsky effect?  rotation/etc
    state.epoch           = DateTime.parse(opm_vals['EPOCH']['val']).new_offset(0).to_time #utc = 0.0 offset
    state.opm_hash        = opm_vals
    state.mass_kg         = opm_vals['MASS']['val'].to_f if opm_vals['MASS']
    state.radius_m        = opm_vals['USER_DEFINED_MEAN_RADIUS']['val'].to_f * 1000.0 if opm_vals['USER_DEFINED_MEAN_RADIUS']
    state.sim_max_dist    = 0
    state.sim_min_dist    = Float::INFINITY
    state.eccentricity    = opm_vals['ECCENTRICITY']['val'].to_f if opm_vals['ECCENTRICITY']
    state.semi_major_axis = opm_vals['SEMI_MAJOR_AXIS']['val'].to_f * 1000.0 if opm_vals['SEMI_MAJOR_AXIS']
    state.running_avg_energy_j = kinetic_energy_j(state) + potential_energy_j(state)
    state.obj_name        = opm_vals['OBJECT_NAME']['val']
    state.gm_m3ps2        = state.mass_kg * $g_const_m3pkgs2   #if there's a difference, lets use the one that has matching masses

    # TODO: This version of the gm constant is not accurate (mass doesn't match the sim)
    # state.gm_m3ps2        = opm_vals['GM']['val'].to_f * 1000.0 ** 3 if opm_vals['GM'] #km3 to m3

    state
  end


  def self.is_same_body(a, b)
    a.obj_name && b.obj_name && a.obj_name == b.obj_name
  end
  
  def setup_rnd
    $rng = GSL::Rng.alloc(GSL::Rng::MT19937_1999, (Time.now.to_f * 100).to_i % 1000000000)

    #TODO seeding didn't seem to work, and RubyGSL has weak documentation, so as a quick fix, 'seed' GSL with rand
    srand((Time.now.to_f * 10000).to_i)
    rand(1000).times.each { |n| $rng.gaussian() }
  end

end

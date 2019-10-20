# methods for accleration and energy

require 'matrix'
require 'gsl'

def total_energy_j(state)
  kinetic_energy_j(state) + potential_energy_j(state)
end

def kinetic_energy_j(state)
  (state.vel_mps.magnitude**2 * state.mass_kg).abs / 2.0
end

def potential_energy_j(state)
  # From Resnick p353
  $g_const_m3pkgs2 * $m_sun_kg * state.mass_kg / state.pos_m.magnitude   #pos releative to j2000 icrs (sun)
end

def accel_from_masses_mps2(ego, bodies)
   accel_mps2 = Vector.zero(3)

   bodies.each do |body|
     unless OrbitalState.is_same_body(ego, body)  #except oneself
       dist_m = ego.pos_m - body.pos_m
       dist_mag_m = dist_m.magnitude

       if (ego.radius_m && dist_mag_m < ego.radius_m) or (body.radius_m && dist_mag_m < body.radius_m)
         collision_detected(body, dist_mag_m, ego)
       end

       accel_mps2 += accel_from_mass_mps2(dist_m, body.mass_kg)   #Profiler: slowest line
     end
   end

   # print_log(ego.obj_name, accel_mps2.magnitude)
   accel_mps2
 end

def accel_from_mass_mps2(dist_m, m_otherbody_kg)
  a_mps2 = $g_const_m3pkgs2 * m_otherbody_kg  / dist_m.magnitude / dist_m.magnitude   #beware the square (precision)

  if dist_m.magnitude <= Float::MIN * 2
    return Vector.zero(3)
  end

  ret = a_mps2 * (dist_m.normalize)  * -1.0   #scalar to vector
  ret
end

# create a temporary state
def test_update_with_accel(body, duration_s, start_accel_mps2)
  start_pos_m = body.pos_m
  start_vel_mps = body.vel_mps  #so we can find avg vel

  end_vel_mps = start_vel_mps + start_accel_mps2 * duration_s
  avg_vel_ms2 = (body.vel_mps + start_vel_mps) /2
  end_pos_m = start_pos_m + avg_vel_ms2 * duration_s

  OrbitalState.new(obj_name: body.obj_name, pos_m: end_pos_m, vel_mps: end_vel_mps, mass_kg: body.mass_kg, sim_min_dist: 10)
end

def update_with_accel(body, duration_s, start_accel_mps2, end_accel_mps2)
  start_vel_mps = body.vel_mps
  avg_accel_mps2 = (start_accel_mps2 + end_accel_mps2) / 2.0

  body.vel_mps = start_vel_mps + avg_accel_mps2 * duration_s
  avg_vel_ms2 = (body.vel_mps + start_vel_mps) /2
  body.pos_m =  body.pos_m + avg_vel_ms2 * duration_s

  body.epoch += duration_s

  p = body.pos_m.magnitude   # position relative to frame center
  body.high_low_finder.check_high_low(p, body.clone)
  body.sim_max_dist = p if  p > body.sim_max_dist
  body.sim_min_dist = p if  p < body.sim_min_dist

  # Methods for finding energy
  # body.running_avg_energy_j = (total_energy_j(body) + body.running_avg_energy_j * $running_avg_factor) / ($running_avg_factor +1)
  body.running_avg_energy_j += (total_energy_j(body).abs + body.running_avg_energy_j ) * $ravg_m  #more efficient

  body
end

# For debugging, print earth distance
def print_earth_dist(body, dist_mag_m, ego)
  threshold_m = 2e8   # moon is 3.84e8
  earth_id    = "399"
  digits      = 15

  if (ego.obj_name.include? earth_id or body.obj_name.include? earth_id) and dist_mag_m < threshold_m
    if body.closest_to_earth_m > dist_mag_m
      body.closest_to_earth_m = dist_mag_m
      puts "R #{ego.radius_m.to_s.rjust(digits)} \t#{body.radius_m.to_s.rjust(digits)} \t#{dist_mag_m.round.to_s.rjust(digits)}, \t#{ego.epoch}"
    end
  end
end

def collision_detected(body, dist_mag_m, ego)
  puts "-----------------=====---------------------"
  puts "######*******   Collision!  #{dist_mag_m}m \t#{ego.pretty_inspect} \t#{body.pretty_inspect}"
  puts "-----------------=====---------------------"
end

# Let's travel back to undergrad physics, rather than copy-pasta formuli from wikipedia
#
# force=mass * acceleration
# force=g_const * (mass1 * mass2)/r**2      #resnick p345
#
# f_asteroid_earth_n = m_asteroid_kg * a_asteroid_earth   #simplification
# a_asteroid_earth = f_asteroid_earth_n  / m_asteroid_kg
# f_asteroid_earth_n = g_const * (m_earth_kg * m_asteroid_kg) / (state.pos_m.magnitude)**2
#
# a_asteroid_earth = g_const * (m_earth_kg * m_asteroid_kg) / (state.pos_m.magnitude)**2  / m_asteroid_kg
# a_asteroid_earth = g_const * m_earth_kg  / (state.pos_m.magnitude)**2

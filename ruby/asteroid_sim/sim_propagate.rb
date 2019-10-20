# Methods to propagate an orbit state for a given duration

require_relative 'orbital_state'
require_relative 'sim_physics'

# Propagate an array of bodies for a duration
def propagateNBody(free_bodies, duration_s)
  propagatePartialNBody([], [], free_bodies, duration_s)
end

# Propagate an array of free bodies, for a duration, given an array of non-moving fixed bodies
def propagatePartialNBody(fixed_bodies_start, fixed_bodies_end, free_bodies_start, duration_s)
  # e.g.  propagate planets etc separate from particles, and re-use the result
  # requires that the fixed_bodies are not sufficiently affected by the free object
  # caution: this uses the fixed bodies at their final position, not initial or avg position

  free_bodies_end = free_bodies_start.map do |ego|
    start_accel_mps2 = accel_from_masses_mps2(ego, fixed_bodies_start + free_bodies_start)
    temp_state       = test_update_with_accel(ego, duration_s, start_accel_mps2) #get updated estimated positions
    temp_state
  end

  #free_bodies_end is now full of temp objects

  free_bodies_start.map do |ego|
    start_accel_mps2 = accel_from_masses_mps2(ego, fixed_bodies_start + free_bodies_start) #optimization: duplicate work
    end_accel_mps2   = accel_from_masses_mps2(ego, fixed_bodies_end + free_bodies_end)
    update_with_accel(ego, duration_s, start_accel_mps2, end_accel_mps2)
  end
end

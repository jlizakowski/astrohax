# astrohax
Quick sketch of asteroid simulation, intended for learning Astrodynamics, trying Google Cloud, and playing with techniques like particle filters.  For production, or even proper research, start fresh with lessons learned.

Disclaimer: Some important things are nice, when stable. Recent changes have quirks / duct tape pending refactoring, and supporting resources are minimum-viable-hacks.

If any of this is useful, I can create a fresh repo with a more solid version of whichever sub-parts are needed.

### Usage
```bash
cd ruby

# Run with defaults
./run_simulation.sh

# Specific examples
./run_simulation.sh "apophis" "2008-01-01" "2028-01-01" 1e7 20 1e3
./run_simulation.sh "2019 MO" "2019-06-22 21:15" "2019-06-22 21:31" 1e4 3 1e0   #collision test

# bonus
octave results/{sim_name}/{sim_name}_particle123.m      #to generate a scatter plot of a particle
open results/{sim_name}/{sim_name}figure_particle0.pdf  #view plot from octave
open results/{sim_name}/forces.fdp.png                  #view graphviz plot of forces 
```

### Simulation Method
The main propagation methods use Verlet integration, split to allow for particles.

```ruby
# Propagate an array of bodies for a duration
def propagateNBody(free_bodies, duration_s)
  propagatePartialNBody([], [], free_bodies, duration_s)
end

# Propagate an array of free bodies, for a duration, given an array of non-moving fixed bodies
def propagatePartialNBody(fixed_bodies_start, fixed_bodies_end, free_bodies_start, duration_s)
  # e.g.  propagate planets etc separate from particles, and re-use the result
  # requires that the fixed_bodies are not sufficiently affected by the free object

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

def update_with_accel(body, duration_s, start_accel_mps2, end_accel_mps2)
  # Update body (without metadata)
  start_vel_mps = body.vel_mps
  avg_accel_mps2 = (start_accel_mps2 + end_accel_mps2) / 2.0

  body.vel_mps = start_vel_mps + avg_accel_mps2 * duration_s
  avg_vel_ms2 = (body.vel_mps + start_vel_mps) /2
  body.pos_m =  body.pos_m + avg_vel_ms2 * duration_s
  
  body.epoch += duration_s
end
```

### License
GPL v3

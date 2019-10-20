# astrohax
Quick sketch of asteroid simulation, intended for learning Astrodynamics, trying Google Cloud, and playing with techniques like particle filters.  For production, or even proper research, start fresh with lessons learned.

Disclaimer: Some important things are nice, when stable. Recent changes have quirks / duct tape pending refactoring, and supporting resources are minimum-viable-hacks.

If any of this is useful, I can create a fresh repo with a more solid version of whichever sub-parts are needed.

### Usage
```
cd ruby

./run_simulation.sh

./run_simulation.sh "apophis" "2008-01-01" "2028-01-01" 1e7 20 1e4
./run_simulation.sh "2019 MO" "2019-06-22 21:15" "2019-06-22 21:31" 1e4 3 1e0   #collision test

# bonus
octave results/{sim_name}/{sim_name}_particle123.m      #to generate a scatter plot of a particle
open results/{sim_name}/{sim_name}figure_particle0.pdf  #view plot from octave
open results/{sim_name}/forces.fdp.png                  #view graphviz plot of forces 
```

### License
GPL v3

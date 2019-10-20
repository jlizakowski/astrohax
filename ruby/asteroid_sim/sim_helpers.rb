# Misc helpers

require 'prime'
require 'date'

#Generate a prime, to reduce harmonics, but primes also can hide lack of harmonics... depending on what you are trying to solve
def nonprime_near(n)
  n = n + 1 while (!Prime.prime?(n.to_i))
  n.to_i
end

def avg_vectors(arr, fname)
  arr.reduce(Vector.zero(3)) { |sum, item| sum + item.send(fname) } / arr.count
end

def avg_floats(arr, fname)
  arr.reduce(0.0) { |sum, item| sum + (item.send(fname) or 0) } / arr.count
end

def assert(bool)
  raise RuntimeError("Assertion is false") unless bool
end

def lookup_opm(query, epoch)
  fn = query_to_opm_filename(query, epoch)

  unless File.exist? fn
    puts "Querying Horizons for #{query}\t @#{epoch}"
    get_ephem_format2x(query, epoch)
    opm_filename = convert_to_opm(query, epoch)
  end
  
  OrbitalState.load_opm(fn)
end

def sign(q)
  q <=> 0.0
end

# Find the lorenz factor, if extreme accuracy is needed and velocity is high
def lorenz_factor(vel_mps)
  beta  = vel_mps / $speed_of_light_mps
  gamma = 1 / (Math.sqrt(1 - beta ** 2))
end

# Print a simple textual graph of the log of n.  For debugging.
def print_log(name, n)
  exp = Math.log10(n).round

  if exp < 0
    puts "#{name[0..4]} \t#{exp}\t#{"-" * exp.abs}"
  else
    puts "#{name[0..4]} \t#{exp}\t#{"+" * exp}"
  end
end

# Find log(n) * sign(n), for use in graphviz diagrams
def log_position(pos)
  return 0 if pos == 0
  (Math.log10(pos.abs) * sign(pos)).to_i.to_f
end

# create png of forces on objects, for debug
def generate_graphviz_force_diagram(bodies, fn_prefix = "")
  out = <<~HEREDOC
    digraph G {
      node [nodesep=2.0, fontsize=20, labelfontcolor="#10101080", fixedsize=true];
      edge [weight=0.1, fontsize=14, minlen=2, color="#10101040", labelfontcolor=blue, labeldistance=4];
  HEREDOC

  bodies.each do |ego|
    # express positions in logarithms, due to ... astronimcal distances
    x = log_position(ego.pos_m[0]).abs
    y = log_position(ego.pos_m[1]).abs

    #magic formula to make the NEO part of the solar system look nice
    sz = (((Math.log10(ego.mass_kg.abs + 1).round(3) / 10.0) + 1) ** 3).round(2) / 70.0
    sz = (sz * 2).round(3)

    name = ego.obj_name.to_s.gsub(/[^a-zA-Z0-9\.\-\_ ]/, "_")
    firstname = name[/^[a-zA-Z0-9_]+/]
    
    #render the body
    out += "  #{firstname} [shape=circle, width=#{sz}, pos=\"#{x * 20},#{y * 20}\"];\n"
  end

  bodies.each do |ego|
    ego_name = ego.obj_name.to_s.gsub(/[^a-zA-Z0-9\.\-\_ ]/, "_")
    ego_firstname = ego_name[/^[a-zA-Z0-9_]+/]

    bodies.each do |body|
      body_name = body.obj_name.to_s.gsub(/[^a-zA-Z0-9\.\-\_ ]/, "_")
      body_firstname = body_name[/^[a-zA-Z0-9_]+/]

      dist  = ego.pos_m - body.pos_m
      accel = accel_from_mass_mps2(dist, body.mass_kg)

      label_val = "%.2e" % accel.magnitude
      label     = "<<font color=\"blue\">#{label_val}</font>>"

      if true || dist.magnitude.abs < 10 #special case
        len = ""
      else
        n   = (Math.log10(dist.magnitude) / 2) ** (1.1)
        len = ", minlen=#{ n.round(2)}"
      end

      #render the connection
      out += "\t#{ego_firstname} -> #{body_firstname} [label=#{label}#{len}];\n"
    end
  end

  out += "}\n"

  File.write("results/#{fn_prefix}/forces.dot", out)

  #generate a png
  `which fdp && fdp results/#{fn_prefix}/forces.dot -s4 -Tpng -oresults/#{fn_prefix}/forces.fdp.png`

end

# print status dots while waiting.....
class StatusPrinter
  def initialize(silence_level = 3) #default: each call is 10^3
    @silence_level = silence_level # 10^silence_level
    @n = 0
    @dots = %W{o t h k e4 e5 M MM\n MMM\n G\n GG\n GGG\n T\n}
    (0..silence_level - 1).each { |e| @dots[e] = '_' }
    @dots[silence_level] = '.'
  end

  def print_status_dots()
    @n += 1
    dotnum = @dots.count.downto(0).find { |exponent| @n % (10 ** exponent) == 0 }
    if dotnum && dotnum
      print @dots[dotnum + @silence_level]
      STDOUT.flush
    end
  end
end



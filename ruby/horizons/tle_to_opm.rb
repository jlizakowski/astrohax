#!/usr/bin/env ruby

# Convert
# input:  Two-line-element data from JPL horizons, plus body info extracted from telnet
# output: An OPM file

# Note: The Horizons code is fragile, meant just to get supporting data available.

require 'pry'
require 'pp'
require 'date'
require_relative './horizons_common'


# The format varies from file to file.
#  'Vol. mean radius, km  = 695700'
#  'Vol. mean radius, km  = 1737.53+-0.03'
#  'Vol. Mean Radius (km) = 6371.01+-0.02'

# parsers for lines
def radius_parse(body_text, ret)
  mass_arr = body_text.scan(/[Rr]adius[, ]+[^=]*=[\t ~]*([0-9\.]+)/)
  mass_arr.flatten!
  if mass_arr.count == 1
    ret[:radius_m] = 1.0 #meters
  else
    ret[:radius_m] = mass_arr.first
  end
end

def mass_parse_method_1(body_text, ret)
  mass_arr = body_text.scan /Mass ([0-9\.\-\+]*)x10[e^]([0-9]+)/m
  mass_arr.flatten!
  if mass_arr.count == 2 and mass_arr.first.length < 1 #no leading number
    mass_arr[0] = 1.0
  end
  ret[:mass] = mass_arr.first.to_f * 10 ** (mass_arr.last.to_f)
end

def mass_parse_method_2(body_text, ret)
  #formats can vary.  try2, different format
  # Mass, 10^24 kg        = ~1988500

  mass_arr = body_text.scan(/[Mm]ass[, ]+[x]*10\^([0-9]+)[ kg]*=[\t ~]*([0-9\.]+)/)
  mass_arr.flatten!

  ret[:mass] = mass_arr.last.to_f * 10 ** mass_arr.first.to_f
end

# parsers for Files
def parse_horizons_body_format2x(body_text)
  ret = {}
  mass_parse_method_1(body_text, ret)
  mass_parse_method_2(body_text, ret) if ret[:mass] < Float::MIN * 10
  radius_parse(body_text, ret)

  #if body has no mass, set a trivial mass of 1kg
  ret[:mass] = 1.0 if ret[:mass] < Float::MIN * 10

  ret
end

def parse_horizons_format2x(text, body_text)
  body         = text[/Ephemeris .*Coordinate system description/m]
  sections     = body.split /\*{50,}/m
  var_sections = sections.grep(/^[^:]+: [^: ]+[^:]*$/)

  params = parse_horizons_body_format2x(body_text)

  var_sections.join.lines.each do |line|
    kv = line.strip.split(":")
    if kv.first and kv.last
      val                             = kv[1..-1].join.strip
      val                             = val.gsub(/\{.*\}/, '').strip.downcase
      params[kv.first.strip.downcase] = val
    end
  end

  date, time           = params['start time'].downcase.gsub(/a.d. /, '').gsub(/tdb/, '').split(" ")
  params['start time'] = DateTime.parse(date + " " + time).to_time

  tle_lines   = sections.grep(/SOE.*EOE/m).join.lines.grep(/[0-9]{5,}/).join
  fields      = tle_lines.split(",")
  field_names = [:jdtdb, :date, :delta_t, :x, :y, :z, :vx, :vy, :vz, :x_s, :y_s, :z_s, :vx_s, :vy_s, :vz_s]
  tle_hash    = {}
  field_names.zip(fields).map { |pair| (tle_hash[pair.first] = pair.last.strip) if pair.first and pair.last }

  tle_hash.each do |k, v|
    if v.to_s.include? 'n.a.'
      tle_hash[k] = 0.0
    end
    if k.to_s.match? /[xyz]/
      tle_hash[k] = v.to_f || 0.0
    end
  end

  [params, tle_hash]
end


def to_opm_file(filename, params, tle_hash)
  mass_to_use_kg = 1e1 #default

  if params[:mass] and params[:mass].to_s.length > 0
    mass_to_use_kg = params[:mass].to_f
  end

  File.open(filename, "w") do |f|
    f.puts <<~HEREDOC
      CCSDS_OPM_VERS    =  2.0
      CREATION_DATE     =  #{Time.now}
      ORIGINATOR        =  tle.rb with Data from JPL Horizons
      OBJECT_NAME       =  #{params["target body name"]}
      OBJECT_ID         =  #{params["target body name"]}
      CENTER_NAME       =  #{params["center body name"]}
      REF_FRAME         =  #{params["reference frame"]}
      TIME_SYSTEM       =  UTC      
      USER_DEFINED_MEAN_RADIUS = #{(params[:radius_m] || "0").to_f} [km]
      COMMENT  State Vector
      EPOCH             =  #{DateTime.parse(tle_hash[:date]).to_time.strftime('%F %T')}
      X                 =  #{tle_hash[:x]}     [km]
      Y                 =  #{tle_hash[:y]}     [km]
      Z                 =  #{tle_hash[:z]}     [km]
      X_DOT             =  #{tle_hash[:vx]}    [km/s]
      Y_DOT             =  #{tle_hash[:vy]}    [km/s]
      Z_DOT             =  #{tle_hash[:vz]}    [km/s]
      COMMENT  Spacecraft parameters                         
      MASS              =  #{mass_to_use_kg }      [kg]
      COV_REF_FRAME = RTN
      CX_X =  #{tle_hash[:x_s]}
      CY_X =  0.0
      CY_Y =  #{tle_hash[:y_s]}
      CZ_X =  0
      CZ_Y =  0
      CZ_Z =  #{tle_hash[:z_s]}
      CX_DOT_X =  0
      CX_DOT_Y =  0
      CX_DOT_Z =  0
      CX_DOT_X_DOT = #{tle_hash[:vx_s]}
      CY_DOT_X =  0
      CY_DOT_Y =  0
      CY_DOT_Z =  0
      CY_DOT_X_DOT = 0
      CY_DOT_Y_DOT = #{tle_hash[:vy_s]}
      CZ_DOT_X =  0
      CZ_DOT_Y =  0
      CZ_DOT_Z =  0
      CZ_DOT_X_DOT =0
      CZ_DOT_Y_DOT =0
      CZ_DOT_Z_DOT = #{tle_hash[:vz_s]}
    HEREDOC
  end # File.open
end

if ARGV.count >= 1          #quick command-line tool
  query = ARGV[0]
  epoch = ARGV[1] || "2008-01-01 00:00"

  ephem_text = File.read(query_to_ephem_filename(query, epoch))
  body_text  = File.read(query_to_body_filename(query, epoch))

  params, tle_hash = parse_horizons_format2x(ephem_text, body_text)

  opm_filename = query_to_opm_filename(query, epoch)
  to_opm_file(opm_filename, params, tle_hash)
  puts "Created: #{opm_filename}"
end

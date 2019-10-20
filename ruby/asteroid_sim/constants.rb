# Constants with sources

require_relative 'regexp_helpers'

# All units are SI units  kg,m,s
$g_const_m3pkgs2       = 6.67430e-11  #m3⋅kg−1⋅s−2            #source: nist, https://physics.nist.gov/cgi-bin/cuu/Value?bg
$g_const_m3pkgs2_stdev = 0.00015e-11  #m3⋅kg−1⋅s−2            #source: nist, https://physics.nist.gov/cgi-bin/cuu/Value?bg

$m_earth_kg         = 5.9722e24       #(5.9722±0.0006)×10e24  #source: wikipedia, https://en.wikipedia.org/wiki/Earth_mass
$m_moon_kg          = 7.34767309e22
$m_sun_kg           = 1.989e30                                #source: google
$speed_of_light_mps = 299792458                               #google.com

$running_avg_factor = 100.0      # "wavelength" of noise: 10 for short-term random walk, 100 for longer-term random walk

#factors for running averages
$ravg_m = 1.0/$running_avg_factor
$ravg_k = 1.0 - $ravg_m



# Horizons OPM Tool

##Goal:
Purpose: Provide data to a simulator being sketched.  Achieve this rapidly (days), given no prior knowledge of the formats or data sources.

Inputs:
 * The object name
 * The epoch / date of the measurement
 * Internet access, to get data from JPL Horizons   

Outputs:
* OPM ephemeris files (selected fields only)
* Supporting data in a subdirectory named 'data'
* Text showing how Horizons telnet is used, and the names of the output files
 
#### Usage
 ```
 ./horizons.rb ganymede 2019-01-01     #get data via telnet
 ./tle_to_opm.rb ganymede 2019-01-01   #process data -> OPM
 ```
 
The tool is made in two parts to minimize telnet traffic for JPL.  Both tools take the same parameters.  The intent is for a script that calls both of these tools.
 
#### The OPM standard
https://public.ccsds.org/Pubs/502x0b2c1.pdf
 
#### Where are the tests? / Disclaimer
This entire repo is a spike / sketch.  This Horizons tool was created as a data source for other parts of the code, and is the minimum viable hack to enable the other tool.

This is intended to be replaced with a proper tool when such tool or data source is found which has the needed data fields.  Those fields include:
* ICRS rectangular barycentric Coordinate System
* Variances / Standard Deviations for position and velocity to enable meaningful monte-carlo simulations
* Mass and radius (for impact checking)
* Available for arbitrary epochs

#### Were other tools considered?

Yes, multiple open-source tools were explored, including:
* skyfield.py
* odmpy 
* spiceypy
* jplephem 
* astropy
* various libraries in Julia

For various reasons, including lack of variance data, these did not fit the immediate need.  However, these could be combined to replace this tool in the future.

#### License
GPL v3
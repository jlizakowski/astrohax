#!/bin/bash
# Query JPL Horizons for ephemeris data, given an object name and date/epoch
          
default_query="apophis"   #for planets, use their numeric code:   399 is earth, 499 mars, 10 sun, 301 moon
default_date="2008-01-01 00:00:00"

query="${1:-$default_query}"
date="${2:-$default_date}"

./horizons/horizons.rb "$query" "$date"  && ./horizons/tle_to_opm.rb "$query" "$date"

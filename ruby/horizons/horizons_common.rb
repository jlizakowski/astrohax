# commmon naming funcitons

def query_to_ephem_filename(query, epoch)
  outfile = "./data/horizons/#{base(query, epoch)}.ephemeris"
  mkdir(outfile)
  outfile
end

def query_to_body_filename(query, epoch)
  outfile = "./data/horizons/#{base(query, epoch)}.body_info"
  mkdir(outfile)
  outfile
end

def query_to_opm_filename(query, epoch)
  outfile = "./data/opm/#{base(query, epoch)}.opm"
  mkdir(outfile)
  outfile
end

private

# @return [String] Query string lacking special characters
def safename(query)
  query.to_s.gsub(/[^a-zA-Z0-9\.\-\_]/, "_")
end

def mkdir(outfile)
  dir = File.dirname(outfile)
  `mkdir -p #{dir}`
end

def base(query, epoch)
  "#{safename(epoch)}/#{safename(query)}_#{safename(epoch)}"
end
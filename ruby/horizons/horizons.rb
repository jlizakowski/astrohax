#!/usr/bin/env ruby

require 'net/telnet'
require 'net/ftp'
require 'uri'
require_relative './horizons_common'

def ftp_file(uri, ftp_filename)
  Net::FTP.open(uri.host) do |ftp|
    ftp.login
    ftp.getbinaryfile(uri.path, ftp_filename)
  end
end

# @return [String] Telnet transcript
def run_telnet_cmds(cmds, fail_regexp = nil)
  log = ""
  sleep(0.1) #to slow down automated scripts and prevent unintended DOS

  horizons = Net::Telnet::new("Host"     => "horizons.jpl.nasa.gov",
                              "Port"     => 6775,
                              "Timeout"  => 10,
                              "Waittime" => 0.1,
                              "Prompt"   => /[:>]/n) #n= ascii 8 bit
  puts "Connecting..."
  begin
    log += horizons.waitfor("String" => 'ystem news updated', "Timeout" => 3)
  rescue
    sleep(1)
  end

  cmds.each do |command|
    sleep(0.1)
    puts "### Sending cmd: #{command}"
    log += horizons.cmd(command) { |c| print c }

    if log.lines.last.include? "Continue ["
      log += horizons.cmd('yes') { |c| print c }
    end

    if fail_regexp && log.match?(fail_regexp)
      puts "\nError: Regexp #{fail_regexp.source} \nmatches: #{log[fail_regexp]}"
      horizons.close
      exit(1)
    end

  end

  horizons.puts("q")
  sleep(0.1)
  horizons.close
  puts #in case the display ended without endline
  log
end

def uri_from_log(log)
  #Text contains: "   Full path   :  ftp://ssd.jpl.nasa.gov/pub/ssd/wld8021.15"

  uriline = log.lines.grep(/ftp/).last.strip
  URI(uriline.strip[/ftp:\/\/.*/])
end

def save_body_info(log, bodyfilename)
  body_info = log.split(/\*{70,}/)[1]
  File.write(bodyfilename, body_info)
end

# @return [Array<String>] Ephem and body filenames
def get_ephem_format2x(query, start_date = "2008-01-01 00:00:00")
  delta_t_s = 10.0

  start_date = DateTime.parse(start_date).strftime('%F %T')
  end_date   = (DateTime.parse(start_date) + delta_t_s / 24.0 / 60.0 / 60.0).strftime('%F %T')

  ftp_filename  = query_to_ephem_filename(query, start_date)
  body_filename = query_to_body_filename(query, start_date)

  unless File.exist? ftp_filename and File.exist? body_filename
    cmds = %W[PAGE\ off #{query} E v @sun frame #{start_date} #{end_date} 10m n j2000 1 1 yes yes 2x f ]

    log = run_telnet_cmds(cmds, /No matches found/)
    uri = uri_from_log(log)

    #save attributes from the log, and from the FTP file, which has different data
    ftp_file(uri, ftp_filename)
    save_body_info(log, body_filename)
  end

  [ftp_filename, body_filename]
end

if $0 == __FILE__
  if ARGV.count >= 1
    puts "Query: #{ARGV[0]} @ #{ARGV[1]}"
    epoch = ARGV[1] || "2008-01-01 00:00"
    ret  = get_ephem_format2x(ARGV[0], epoch)
    puts "Created: #{ret.inspect}"
  end
end








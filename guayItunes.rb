require 'optparse'
require 'cgi'
require 'sqlite3'

# default options
options = {
  :verbose     => false,
  :iTunesFile  => nil,
  :guayDB      => "~/.guayadeque/guayadeque.db"
}


ARGV.options do |o|
  script_name = File.basename($0)
  
  o.set_summary_indent('  ')
  o.banner =    "Usage: #{script_name} [OPTIONS]"
  o.define_head "transfers rating information from iTunes to Guayadeque"
  o.separator   "requires that you first export your library as an XML file"
  o.separator   "from within iTunes"
  o.separator   ""
  
  o.on("-f", "--iTunesFile=path", String,
       "path to the iTunes File") { |options[:iTunesFile]| }

  o.on("-g", "--guayDB=path", String,
       "path to the guayadeque database",
       "default: #{options[:guayDB]}")   { |options[:guayDB]| }

  o.on("-v", "--verbose") { |options[:verbose]| }

  o.separator ""

  o.on_tail("-h", "--help", "Show this help message.") { puts "";puts o;puts "";exit }
  
  o.parse!
end


#check params
raise "path to iTunes XML file is required" if options[:iTunesFile].nil?


#parse iTunes XML file
infile = File.new(options[:iTunesFile])

$stderr.puts "parsing iTunes XML..." if options[:verbose]
indict = false
filenames = {}
rating = nil
infile.each{|line|
  if line =~ /\<dict\>/
    indict = true
  elsif line =~ /\<\/dict\>/
    indict = false
    rating = nil
  elsif indict
    if line =~ /\<key\>Rating\<\/key\>\<integer\>(\d+)\<\/integer\>/
      rating = $1
    elsif line =~ /\<key\>Location\<\/key\>\<string\>file\:\/\/([^\/]+\/)+(.+)\<\/string\>/
      filename = $2
      unless rating.nil?
        filenames[filename] = rating
      end
    end
  end
}


def prepareLocation(iTunesLocation) 
  # change %20 to spaces, etc.
  iTunesLocation = CGI.unescape(iTunesLocation.gsub("+","%2B"))
  return iTunesLocation;    
end

def safeForSql(sqlstring)
  sqlstring.gsub("'","''").gsub('"','\"').gsub("&#38;","&").gsub("&#62;",">").gsub("&#60;","<").strip
end


#open guay DB
db = SQLite3::Database.new(File::expand_path(options[:guayDB]))
$stderr.puts "Updating database..." if options[:verbose]
songNames = []
filenames.each{|filename,rating|
  a = safeForSql(prepareLocation(filename))
  b = "UPDATE songs SET song_rating = #{rating.to_i/20} where song_filename = '#{a}'"
  $stderr.puts b if options[:verbose]
  c = db.execute(b)
}

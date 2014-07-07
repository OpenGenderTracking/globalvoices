libdir = File.expand_path(File.join(File.dirname(__FILE__), 'lib/'))
srcdir = File.expand_path(File.join(File.dirname(__FILE__), 'src/'))
$LOAD_PATH.unshift(srcdir) unless $LOAD_PATH.include?(srcdir)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require 'yaml'
require 'json'
require 'confstruct'
#require 'feed_parser'
require 'xml_parser'
#require 'debugger'

# which collection are we processing? Make sure one was provided.
collection = ARGV[0]

if (collection.nil?)
  puts "Please pass a collection name to process. Available collections are in the config.yaml file."
  exit;
end

# get our configuration data
config = Confstruct::Configuration.new(
  YAML.load_file(
    File.expand_path(
      File.join(File.dirname(__FILE__), 'config.yaml')
    )
  )
)

# iterate over all the files, and convert them to the json format.
files_to_convert = Dir[File.expand_path(File.join(File.dirname(__FILE__), 
  config.data.path, 
  collection, 
  config.collections[collection].path))
]

files_to_convert.each do |feed_path|
  feed = File.open(feed_path, 'r').read
  gb = Parsers::XMLParser.new(feed, collection, config)
  gb.process
end

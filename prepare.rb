libdir = File.expand_path(File.join(File.dirname(__FILE__), 'lib/'))
srcdir = File.expand_path(File.join(File.dirname(__FILE__), 'src/'))
$LOAD_PATH.unshift(srcdir) unless $LOAD_PATH.include?(srcdir)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require 'yaml'
require 'json'
require 'confstruct'
require 'feed_parser'

# which collection are we processing?
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

# init a connection to our redis processing queue
# redis = Redis.new(:host => config.redis.host, :port => config.redis.port)

# iterate over all the files, and convert
files_to_convert = Dir[File.expand_path(File.join(File.dirname(__FILE__), 
  config.data.path, 
  collection, 
  config.collections[collection].path))
]

files_to_convert.each do |feed_path|
  feed = File.open(feed_path, 'r').read
  gb = Parsers::FeedParser.new(feed, collection, config)
  gb.process
end



# # get the file containing the globalvoices data
# feed_path = File.expand_path(File.join(File.dirname(__FILE__),
#   "../", @@config["collections"]["globalvoices"]["path"],
#   @@config["collections"]["globalvoices"]["filename"]
#   )
# )
# puts feed_path
# feed = File.open(feed_path, 'r').read

# # Load global voices articles
# gb = Parsers::GlobalVoicesLocalFeed.new(feed, "globalvoices")
# gb.process

# # token up all global voices articles.
# gvarticles = Dir.glob(File.join(File.dirname(__FILE__), "../data/globalvoices/*.json"))
# count = gvarticles.size - 1

# decomposer = Decomposer::Tokens.new
# gvarticles.each do |f|
#   article = Article.new(File.expand_path(File.join(File.dirname(__FILE__), "../", f)))
#   decomposer.process(article)
# end
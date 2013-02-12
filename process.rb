libdir = File.expand_path(File.join(File.dirname(__FILE__), 'lib/'))
srcdir = File.expand_path(File.join(File.dirname(__FILE__), 'src/'))
$LOAD_PATH.unshift(srcdir) unless $LOAD_PATH.include?(srcdir)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require 'yaml'
require 'json'
require 'confstruct'
require 'feed_parser'
require 'redis'
require 'evented_redis'
require 'thread'

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
redis = Redis.new(:host => config.redis.host, :port => config.redis.port)

# iterate over all the article files, and publish them to be processed.
files_to_process = Dir[File.expand_path(File.join(File.dirname(__FILE__), 
  config.articles.path, 
  collection, 
  "*.json")
  )
]

# EM.run do
@pub = Redis.new(:host => config.redis.host, :port => config.redis.port)
@sub = Redis.new(:host => config.redis.host, :port => config.redis.port)

processed_files = 0

files_to_process.each do |article_path|
  puts "Processing: #{article_path}"
  @pub.publish "process_article", article_path
end

@sub.subscribe('process_article_done') do |on|
  on.message do |channel, article_path|

    if channel == 'process_article_done'

      processed_files += 1

      # TODO: this doesn't actually get called right now.
      
      if (processed_files + 1 == files_to_process.length)
        puts "done processing"
      end
    end
  end
end
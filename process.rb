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
require 'eventmachine'
require 'em-hiredis'
require 'debugger'

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

# iterate over all the article files, and publish them to be processed.
files_to_process = Dir[File.expand_path(File.join(File.dirname(__FILE__), 
  config.articles.path, 
  collection, 
  "*.json")
  )
]

EM.run do
  
  # init a connection to our redis processing queue
  # publishing service
  @pub = EM::Hiredis.connect("redis://#{config.redis.host}:#{config.redis.port}/4")
  # subscribing service
  @sub = EM::Hiredis.connect("redis://#{config.redis.host}:#{config.redis.port}/4")
  # not evented connection for status checking and updating.
  @read = Redis.new(:host => config.redis.host, :port => config.redis.port)
  

  # first request a new job
  job_request_id = UUID.generate()
  job_id = nil

  # subscribe to relevant channels:
  # 1. announcing when article is done.
  @sub.subscribe('process_article_done')
  @sub.subscribe(job_request_id)

  # request a new id for the job.
  @pub.publish 'new_job', job_request_id

  @sub.on(:message) do |channel, message|
    
    case channel

    # we've recieved a new job assigned by the server
    # now process the files.  
    when job_request_id
      
      # save job id.
      job_id = message

      # create a counter for new job that will track file progress.
      @pub.set message, 0

      files_to_process.each do |article_path|
        @pub.publish "process_article", { :path => article_path, :job_id => message }.to_json()
      end
      puts "new job id recieved: #{message}"
    
    # an article was done processing. We're only using this for status
    # alerts at this point. 
    when 'process_article_done'
      
      message = JSON.parse(message)
      article_path = message["path"]
      puts "Done processing: #{article_path}"

    end
  end

  # Poll our file counter in redis. Much more thread safe.
  # when we've processed N files == to the number of original files
  # we can stop the script.
  # TODO: how do we want to handle fault tolerance here?
  EM.add_periodic_timer(1) do
    
    value = @read.get(job_id)
    puts "#{job_id} processed files: #{value}"
    value = value.to_i

    # if all files are processed, kill the process.
    if (value + 1 >= files_to_process.length)
      @read.del job_id
      puts "done processing #{job_id}"
      EM.stop
    end
  end
end
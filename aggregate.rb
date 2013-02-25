libdir = File.expand_path(File.join(File.dirname(__FILE__), 'lib/'))
srcdir = File.expand_path(File.join(File.dirname(__FILE__), 'src/'))
$LOAD_PATH.unshift(srcdir) unless $LOAD_PATH.include?(srcdir)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require 'yaml'
require 'json'
require 'confstruct'

# get our configuration data
config = Confstruct::Configuration.new(
  YAML.load_file(
    File.expand_path(
      File.join(File.dirname(__FILE__), 'config.yaml')
    )
  )
)

# which collection are we processing?
collection = ARGV[0]

if (collection.nil?)
  puts "Please pass a collection name to process. Available collections are in the config.yaml file."
  exit;
end

gvarticles = Dir.glob(File.join(File.dirname(__FILE__), "articles/#{collection}/*.json"))
count = gvarticles.size - 1

time = Time.now().strftime('%Y_%m_%d')

output_all = File.open("assets/#{time}_global_voices_#{collection}_all.csv", "wb")
output_just_names = File.open("assets/#{time}_global_voices_#{collection}_names.csv", "wb")

output_all.write("id,pubdate,byline,gender_by_pronoun,gender_by_byline\n")
output_just_names.write("name,likely_byline_gender\n")

cache = {}

gvarticles.each do |a|
  file = File.open(a, "r")
  body = file.read
  article = JSON.parse(body)

  if (article["byline"])

    line_all = article["id"] + "," + 
           article["pub_date"] + "," +
           article["byline"] + "," +
           article["metrics"]["pronouns"]["result"] + "," +
           article["metrics"]["byline_gender"]["result"] + 
           "\n"
    
    line_names = article["byline"] + "," + 
      article["metrics"]["byline_gender"]["result"] + 
      "\n"

    if (!cache[line_all]) 
      output_all.write(line_all)
      cache[line_all] = 1
    end

    if (!cache[line_names]) 
      output_just_names.write(line_names)
      cache[line_names] = 1
    end
  end
end

output_all.flush
output_all.close
output_just_names.flush
output_just_names.close

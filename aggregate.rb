libdir = File.expand_path(File.join(File.dirname(__FILE__), 'lib/'))
srcdir = File.expand_path(File.join(File.dirname(__FILE__), 'src/'))
$LOAD_PATH.unshift(srcdir) unless $LOAD_PATH.include?(srcdir)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require 'yaml'
require 'json'
require 'confstruct'
require 'debugger'

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

category = nil
if (ARGV[1])
  category = ARGV[1]
  "Generating aggregate for #{category} articles only."
end


gvarticles = Dir.glob(File.join(File.dirname(__FILE__), "articles/#{collection}/*.json"))
count = gvarticles.size - 1

time = Time.now().strftime('%Y_%m_%d')

cat_name = ""
if (!category.nil?)
  cat_name = "-#{category}"
end

output_all = File.open("assets/#{time}_global_voices_#{collection}_all#{cat_name}.csv", "wb")
output_just_names = File.open("assets/#{time}_global_voices_#{collection}_names#{cat_name}.csv", "wb")

output_all.write("id,pubdate,byline,gender_by_pronoun,gender_by_byline\n")
output_just_names.write("name,likely_byline_gender\n")

cache = {}

gvarticles.each do |a|
  file = File.open(a, "r")
  body = file.read
  article = JSON.parse(body)

  begin
    if (article["byline"])

      add_article = false
      if (category.nil?)
        add_article = true
      else
        # check if article has such categories
        if (article["categories"].index(category) != nil)
          add_article = true
        end
      end

      if (add_article)
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
  rescue
    puts a
  end
end

output_all.flush
output_all.close
output_just_names.flush
output_just_names.close

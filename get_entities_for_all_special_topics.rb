libdir = File.expand_path(File.join(File.dirname(__FILE__), 'lib/'))
srcdir = File.expand_path(File.join(File.dirname(__FILE__), 'src/'))
$LOAD_PATH.unshift(srcdir) unless $LOAD_PATH.include?(srcdir)
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require 'json'
require 'yaml'
require 'confstruct'
require 'xml_parser'
require 'net/http'
require 'time'
require 'date'

#load configuration file 
config = Confstruct::Configuration.new(
  YAML.load_file(
    File.expand_path(
      File.join(File.dirname(__FILE__), 'config.yaml')
    )
  )
)

#define which files to convert
collection="full"

files_to_convert = Dir[File.expand_path(File.join(File.dirname(__FILE__),
  config.data.path,
    collection,
      config.collections[collection].path))
]

articles = []

#fetch all articles in the listed collection
files_to_convert.each do |feed_path|
  feed = File.open(feed_path, 'r').read
  gb = Parsers::XMLParser.new(feed, collection, config)
  puts feed_path
  articles.concat gb.fetch_articles
end

# Load all special topic pages
Dir.glob("articles/pages/*").each do |special_page_json|

  
  #Collect slugs from articles that are in the special topics page
  special_page_id = special_page_json.gsub(/.*\/(.*?)\..*/,'\1')

  special_page_hash = JSON.parse(File.open(special_page_json).read)


  gv_slugs = special_page_hash["link_hrefs"].collect{|link|
    if(!link.index("globalvoicesonline").nil?)
      link.gsub(/(.*)\//,'\1').gsub(/.*\//,"") 
    else
      nil 
    end
  }.reject{|n|n.nil?}

  if !["228481","32433"].include? special_page_hash["post_parent"]#GV specific: all special pages have this as parent
    puts "rejecting #{special_page_json}: #{special_page_hash['post_parent']}  : #{special_page_hash['title']}: #{gv_slugs.size} articles"
    next
  end

  puts "processing #{special_page_json}: #{special_page_hash['title']}: #{gv_slugs.size} articles"

#return all articles that are listed in the collection
  page_articles = articles.collect{|article|
    if(gv_slugs.include? article["slug"])
      article
    else
      nil
    end
  }.reject{|n|n.nil?}

  # output metadata
  output_filename ="special_page_#{special_page_id}_background.csv"
  File.open("reports/page_entities/#{output_filename}", 'w') {|f|
    dates = special_page_hash['internal_link_dates'].sort
    f.write(["id","title","pub_date","article_count","first_date","end_date"].join(",")+"\n")
    f.write("#{special_page_id},#{special_page_hash['title'].gsub(/,/,'')},#{Time.parse(special_page_hash['pub_date']).to_s},#{gv_slugs.size},#{dates[0]},#{dates[-1]}")
  }

  entities = {"organizations"=>{}, "cities"=>{}, "places"=>{}, "people"=>{}}

#return data about articles in this collection
  page_articles.each do |article|
    print "."
    STDOUT.flush
    ## http://cliff.mediameter.org/process
    ## collect CLIFF entities for each of these articles
    #puts article["title"]
    article["body"]
    uri = "http://civicprod.media.mit.edu:8080/CLIFF/parse/text"
    begin
      response = Net::HTTP.post_form(URI(uri), {"q" => article["body"]})
    rescue
      puts "unable to fetch CLIFF for #{article["slug"]}"
    end
    begin
      article_ents = JSON.parse(response.body)
    rescue
      puts "unable to parse JSON for #{article["slug"]}"
    end
    if(!article_ents.nil? and !article_ents["results"].nil?)
      ["organizations", "people"].each do |type|
        if(!article_ents["results"][type].nil?)
          article_ents["results"][type].each do |entity|
            #puts entity
            #puts "#{entity["name"]}: #{entity["count"]}: #{entities[type][entity["name"]]}"
            if entities[type][entity["name"]].nil?
              entities[type][entity["name"]] = {
                "first_date"=>article["pub_date"],
                "last_date"=>article["pub_date"],
                "count"=>0} 
            end
            latest_date = entities[type][entity["name"]]["last_date"]
            entities[type][entity["name"]]["last_date"] = article["pub_date"] if article["pub_date"] > latest_date
            entities[type][entity["name"]]["count"] += entity["count"].to_i
          end
        end
      end

      #puts article_ents.to_json
      if(!article_ents["results"].nil? and !article_ents["results"]["places"].nil? and
         !article_ents["results"]["places"]["about"].nil? and
         !article_ents["results"]["places"]["about"]["cities"].nil?)
        article_ents["results"]["places"]["about"]["cities"].each do |city|
          city_name = city["name"]
          if entities["cities"][city_name].nil?
            entities["cities"][city_name] = {
              "first_date"=>article["pub_date"], 
               "last_date"=>article["pub_date"],
              "count"=> 0} 
          end
          latest_date = entities["cities"][city_name]["last_date"]
          entities["cities"][city_name]["last_date"] = article["pub_date"] if article["pub_date"] > latest_date
          entities["cities"][city_name]["count"] += 1
          entities["cities"][city_name]["lat"] = city["lat"]
          entities["cities"][city_name]["lon"] = city["lon"]
        end
      end
      if(!article_ents["results"].nil? and !article_ents["results"]["places"].nil? and
         !article_ents["results"]["places"]["mentions"].nil?)
        article_ents["results"]["places"]["mentions"].each do |place|
          place_name = place["name"]
          if entities["places"][place_name].nil?
            entities["places"][place_name] =  {
              "first_date"=>article["pub_date"], 
               "last_date"=>article["pub_date"],
              "count"=> 0} 
          end
          latest_date = entities["places"][place_name]["last_date"]
          entities["places"][place_name]["last_date"] = article["pub_date"] if article["pub_date"] > latest_date
          entities["places"][place_name]["count"] += 1
          entities["places"][place_name]["lat"] = place["lat"]
          entities["places"][place_name]["lon"] = place["lon"]
        end
      end
    end
    #puts response.body //this must show the JSON contents
  end
  puts


# NOW GENERATE A REPORT ON THE SPECIAL COVERAGE PAGE FOR PEOPLE, ORGS, CITIES, and PLACES
  entities.each_key do |type|
    output_filename="special_page_#{special_page_id}_#{type}.csv"
    File.open("reports/page_entities/#{output_filename}", 'w') {|f| 
      f.write "#{type},count,first_date,last_date,lat,lon\n"
      entities[type].each do |entity, count|
        # NOTE THAT WE CAN GET THE TIME, NOT JUST THE DATE
        f.write [entity.gsub(/,/,''),
                 count['count'],
                 Time.parse(count['first_date']).to_s,
                 Time.parse(count['last_date']).to_s,
                 count["lat"],
                 count["lon"]
                 ].join(",") + "\n"
      end
    }
  end
end



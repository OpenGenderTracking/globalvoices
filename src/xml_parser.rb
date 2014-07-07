require 'xml'
require 'php_serialize'
require 'sanitize'
require 'parser'
require 'nokogiri'

module Parsers
  class XMLParser < Parsers::Default

    def fetch
      feed = XML::Parser.string(@data)
      feed = feed.parse

      feed.find('//channel/item').each do |entry|
        self.parse(entry)
      end

    end

    def generate_id(article)
    
      if (article["id"])
        url_id = article["id"]
      end

      if (url_id.nil?)
        return super(article)
      else
        return url_id
      end
    end

    def parse(entry)
      self.save(just_parse(entry))
    end

    def fetch_articles
      feed = XML::Parser.string(@data)
      feed = feed.parse

      articles = []

      feed.find('//channel/item').each do |entry|
        articles << self.just_parse(entry)
      end
      return articles
    end

    def just_parse(entry)
      
      article = {}

      article["url"] = entry.find("link").first.content
      article["id"] = entry.find("wp:post_id").first.content rescue self.generate_id(entry)
      
      # remove html content tags.
      content = entry.find("content:encoded").first.content
      article["body"] = Sanitize.clean(content)
      article["original_body"] = content
      article["title"] = entry.find("title").first.content
      article["pub_date"] = entry.find("pubDate").first.content
      article["post_parent"] = entry.find("wp:post_parent").first.content
      article["post_name"] = entry.find("wp:post_name").first.content

      #add all outgoing link hrefs
      article["link_hrefs"] = []
      parsed_content = Nokogiri::HTML(content)

      parsed_content.css("a").each do |link|
        article["link_hrefs"] << link.attributes["href"].value if !link.attributes["href"].nil?
      end
      
      # extract the date associated with internal links
      # in future verisons, do an actual lookup against the
      # metadata associated with the speific page in question
      article["internal_link_dates"] = []
      article["link_hrefs"].each do |href|
        if href.include?("globalvoicesonline")
          datematch = /([0-9][0-9][0-9][0-9]\/[0-9][0-9]\/[0-9][0-9])/.match(href)
          if(datematch and datematch.size>0)
            date = datematch[0]
            article["internal_link_dates"] << date
          end
        end
      end

      article["slug"] = nil
      slug = entry.find("wp:post_name")
      article["slug"] = slug.first.content if !slug.nil?
        
      categories = []
      entry.find("category").each do |cat|
        categories << cat.content
      end
      article["categories"] = categories || []

      # do we have translator data? if so, prefer it over the creator. If not
      # use the creator.
      source_meta = entry.find("wp:postmeta/wp:meta_key[text()='source_meta']")
      if (source_meta.length > 0)
        source_value = entry.find("wp:postmeta/wp:meta_key[text()='source_meta']/following-sibling::wp:meta_value").first.content
        if (source_value != "")
          source_value = PHP.unserialize(source_value)
          article["byline"] = source_value["author_name"]
        else
          article["byline"] = nil
        end
        article["translated"] = true
      else
        article["byline"] = entry.find("dc:creator").first.content
        if (article["byline"] == "")
          article["byline"] = nil
        end
        article["translated"] = false
      end

      return article
      
    end

  end
end

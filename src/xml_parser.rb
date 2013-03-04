require 'xml'
require 'php_serialize'
require 'sanitize'
require 'parser'

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
      
      article = {}

      article["url"] = entry.find("link").first.content
      article["id"] = entry.find("wp:post_id").first.content rescue self.generate_id(entry)
      
      # remove html content tags.
      content = entry.find("content:encoded").first.content
      article["body"] = Sanitize.clean(content)
      article["original_body"] = content
      article["title"] = entry.find("title").first.content
      article["pub_date"] = entry.find("pubDate").first.content

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

      self.save(article)
      
    end

  end
end
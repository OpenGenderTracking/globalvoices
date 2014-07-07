require 'date'
require 'json'

json = JSON.load(File.open(ARGV[0]).read)

weeks=["00","01","02","03","04","05","06","07","08","09",10,
         11,12,13,14,15,16,17,18,19,20,
         21,22,23,24,25,26,27,28,29,30,
         31,32,33,34,35,36,37,38,39,40,
         41,42,43,44,45,46,47,48,49,50,
         51,52]

years = [2000,2001,2002,2003,2004,2005,2006,2007,2008,2009,2010,2011,2012,2013,2014]
story_weeks = {}
years.each{|year|weeks.each{|week| story_weeks[year.to_s+week.to_s]=0}}

json["internal_link_dates"].each do |date|
    week = Date.parse(date).strftime("%Y%U")
    story_weeks[week] += 1
end

years.each{|year|weeks.each{|week|
  weeknum = year.to_s+week.to_s
    puts "#{weeknum},#{story_weeks[weeknum]}"
}}

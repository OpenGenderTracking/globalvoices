require 'json'
require 'date'

files = Dir.glob("../articles/pages/*")

earliest_date = Date.parse(Time.new.to_s)

files.each do |file|
  topic = JSON.load(File.open(file).read)
  topic["internal_link_dates"].each do |timestamp|
    timestamp_date = Date.parse(timestamp)
    earliest_date = timestamp_date if timestamp_date < earliest_date
  end
end

puts "Earliest date: #{earliest_date.to_s}"

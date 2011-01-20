#!/usr/bin/env ruby

require 'yaml'
require 'rubygems'
require 'simple-rss'
require 'open-uri'
require 'hipchat'

def var_dump(message, var)
	print message, " class (#{var.class}) ", var.inspect, "\n"
end

# read config
config = YAML.load_file('/home/hip_rss/hip_rss.yaml')

# read previous update times
info_file = config['info_file'];
update_info = YAML.load_file(info_file) if File.exists?(info_file)
if update_info == nil
	update_info = {}
end

# loop through our feed definitions
for feed_def in config['feed_defs']
	feed_id = feed_def['id']
	hipchat_message = "";
	rss = SimpleRSS.parse open(feed_def['feed'])
	pubDateKey = if rss.items.first.keys.include?(:pubDate) then
					:pubDate
				else
					:updated
				end
	feed_items = rss.items.sort {|x,y| x[pubDateKey] <=> y[pubDateKey] }; 
	last_update = feed_items.last[pubDateKey]
	previous_update = update_info[feed_id]
	
	for item in feed_items
		if previous_update == nil || item[pubDateKey] > previous_update
			if (hipchat_message.length > 0)
				hipchat_message = hipchat_message + "<br />"
			end
			author = item[:author];
			hipchat_message << "<a href='#{item.link}'>#{item.title}</a>"
			if item[:author] != nil
				hipchat_message << " / #{item.author}"
			end
		end
	end
	
	if (hipchat_message.length > 0)
		hipchat_client = HipChat::Client.new(feed_def['key'])
		result = hipchat_client[feed_def['room']].send(feed_def['user'], hipchat_message, true)
		if result.parsed_response.kind_of?(String)
			print "hipchat client: #{result}\n"
		end
	end
	
	update_info[feed_id] = last_update
end

# Write out last updated times
File.open(info_file, 'w') do |f|
	YAML.dump(update_info, f)
end

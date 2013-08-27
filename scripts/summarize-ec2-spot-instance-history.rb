#!/usr/bin/env ruby

#
# A script that takes the output of the ec2-describe-spot-price-history command
# summarizing the pricing information for each combination of instance type and
# availability zone and calculating an effective price over the provided data's
# duration.
#
# Usage:
#     ec2-describe-spot-price-history | ./summarize-ec2-spot-instance-history.rb
#     ec2-describe-spot-price-history --region us-west-1 -d "Linux/UNIX" | ./summarize-ec2-spot-instance-history.rb
#

require 'date'
require 'optparse'

#
# Parse parameters
#

options = {}
options[:separator] = "\t"
options[:summarize] = false

OptionParser.new do |opts|
  opts.on("--comma", "Separate output with commas (intead of tabs)") do |comma|
    if comma
      options[:separator] = ","
    end
  end
  opts.on("--summarize", "Summarizes results for an instance type across all availability zones") do |summarize|
    options[:summarize] = summarize
  end
end.parse!

separator = options[:separator]

display_summary = options[:summarize]
display_detailed = ! display_summary

# convert the spot data into a list of fields
raw = STDIN.read
lines = raw.split "\n"
lines.delete_if { |l| l.strip.empty? || l.match("^#") }
data = lines.map { |l| l.split "\t" }

# fields (as returned by ec2-describe-spot-price-history)
#
# 0             SPOTINSTANCEPRICE
# 1 price       0.010000
# 2 date        2013-02-04T15:14:08-0800
# 3 type        m1.small
# 4 OS          Linux/UNIX
# 5 zone        us-west-1a

PRICE = 1
DATE = 2
TYPE = 3
OS = 4
ZONE = 5
REGION = 6  # injected below in "Preprocess"


#
# Preprocess
#

# inject some types
data.map do |d|
  d[PRICE] = d[PRICE].to_f
  d[DATE] = DateTime.parse d[DATE]

  # extract region from zone
  d << d[ZONE][0, (d[ZONE].length - 1)]

  d
end
data.sort! { |a,b| a[DATE] <=> b[DATE] } # sort by date ascending


#
# Extract unique instance types and zone for summarization
#

regions = data.map { |l| l[REGION] }.uniq.sort
instance_types = data.map { |l| l[TYPE] }.uniq.sort
zones = data.map { |l| l[ZONE] }.uniq.sort
oses = data.map { |l| l[OS] }.uniq.sort

if regions.length != 1
  STDERR.puts "Unexpected multiple regions."
  exit 1
end

region = regions.first

# Given an array of sorted spot instance pricing information rows,
# calculate their min, max, and effective price over the duration
#
# returns [min, max, effective]
def summarize_price_information(arr)
  if arr.length == 0
    return [0, 0, 0]
  end

  min_price = max_price =  arr.first[PRICE]
  effective_price = 0
  duration = arr.last[DATE] - arr.first[DATE]


  arr.each_with_index do |row, index|
    if index >= (arr.length - 1) then next end

    price = row[PRICE]

    if price < min_price; min_price = price end
    if price > max_price; max_price = price end

    delta = arr[index + 1][DATE] - arr[index][DATE] # the duration between the last price entry and now

    effective_price += (delta / duration) * price   #
  end

  [min_price, max_price, effective_price]
end


#
# Print a summary for each zone/instance type/OScombination
#

instance_types.each do |type|
  rows_of_type = data.select { |r| r[TYPE] == type }

  oses.each do |os|
    rows_of_os = rows_of_type.select { |r| r[OS] == os }

    zone_results = []
    
    zones.each do |zone|
      rows_of_zone = rows_of_os.select { |r| r[ZONE] == zone }

      # individual type, os, zone price summary
      result = [type, os, zone] + summarize_price_information(rows_of_zone).map { |p| "%.5f" % p }
      if display_detailed
        puts result.join(separator)
      end

      # store all price summaries for this configuration for later reporting
      zone_results << result
    end
    
    zone_prices = zone_results.map { |r| r[5].to_f }.select { |p| p > 0 }
    if zone_prices.length == 0; zone_prices << 0.0 end

    if display_summary
      puts [type, os, region, zone_prices.minmax, "%.5f" % (zone_prices.reduce(:+) / zone_prices.length)].flatten.join(separator)
    end

  end
end

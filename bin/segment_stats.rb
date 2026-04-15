#!/usr/bin/env ruby
=begin

Calculate segment statistics for transcript files

    segment_stats.rb file1

Outputs statistics per file including:
- Average segment length
- Average gap between segments
- Total number of segments
- Total duration of all segments

=end

require_relative '../lib/models'

raise "Usage: segment_stats.rb <file>" if ARGV.length != 1

sample = Sample.new
fn = ARGV[0]
string = File.read fn
sample.init_from(string:, fn:)

stats = sample.segment_statistics

puts "file\tsegments\tavg_length\tavg_gap\ttotal_length"
stats.each do |file, data|
  puts [
    file,
    data[:count],
    data[:avg_length].round(3),
    data[:avg_gap].round(3),
    data[:total_length].round(3)
  ].join("\t")
end

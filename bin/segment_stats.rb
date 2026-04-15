#!/usr/bin/env ruby
=begin

Calculate segment statistics for transcript files

    segment_stats.rb [options] <file>

Options:
    --combined, -c    Treat all segments as single document (ignore file column)

Outputs statistics per file including:
- Average segment length
- Average gap between segments
- Total number of segments
- Total duration of all segments

Examples:
    segment_stats.rb transcript.tsv         # Per-file statistics
    segment_stats.rb --combined multi.tsv   # Combined statistics

=end

require_relative '../lib/models'

# Parse arguments
combined = false
filename = nil

ARGV.each do |arg|
  case arg
  when '--combined', '-c'
    combined = true
  when /^-/
    STDERR.puts "Unknown option: #{arg}"
    STDERR.puts "Usage: segment_stats.rb [--combined|-c] <file>"
    exit 1
  else
    filename = arg
  end
end

unless filename
  STDERR.puts "Usage: segment_stats.rb [--combined|-c] <file>"
  exit 1
end

unless File.exist?(filename)
  STDERR.puts "Error: File not found: #{filename}"
  exit 1
end

sample = Sample.new
string = File.read filename
sample.init_from(string:, fn: filename)

stats = sample.segment_statistics(combined: combined)

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

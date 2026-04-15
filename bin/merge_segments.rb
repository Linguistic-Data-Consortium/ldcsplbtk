#!/usr/bin/env ruby
=begin

Merge consecutive transcript segments when gap is below threshold

    merge_segments.rb <threshold> <file>

Arguments:
    threshold    Maximum gap in seconds for merging (e.g., 0.5)
    file         Input transcript file (TSV, JSON, or CTM format)

Output:
    TSV format with merged segments written to stdout

Behavior:
- Merges consecutive segments within the same file when gap < threshold
- Preserves speaker boundaries (only merges if same speaker)
- Does NOT merge segments from different source files
- Segments are sorted by begin time before merging

Examples:
    # Merge segments with gaps less than 0.5 seconds
    merge_segments.rb 0.5 transcript.tsv > merged.tsv

    # Merge segments with gaps less than 1.0 seconds
    merge_segments.rb 1.0 input.json > merged.tsv

=end

require_relative '../lib/models'

if ARGV.length != 2
  STDERR.puts "Usage: merge_segments.rb <threshold> <file>"
  STDERR.puts "  threshold: Maximum gap in seconds for merging (e.g., 0.5)"
  STDERR.puts "  file:      Input transcript file"
  exit 1
end

threshold = ARGV[0].to_f
filename = ARGV[1]

unless File.exist?(filename)
  STDERR.puts "Error: File not found: #{filename}"
  exit 1
end

if threshold < 0
  STDERR.puts "Error: Threshold must be non-negative"
  exit 1
end

# Load and parse input
sample = Sample.new
string = File.read filename
sample.init_from(string: string, fn: filename)

# Merge segments
merged = sample.merge_segments(threshold: threshold)

# Output merged segments
merged.print(strip_extensions: false)

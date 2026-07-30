#!/usr/bin/env ruby
=begin

reports total overlapping speech duration per file, writing to stdout.

    count_overlap.rb file1

Two segments overlap when their time spans intersect, regardless of speaker.
Every overlapping pair contributes the length of its intersection, so a span
covered by three segments at once is counted for each pair.

The output is a two column tsv of file and overlap, in seconds:

    file    overlap
    interview   1.25

=end

require_relative '../lib/models'

puts "file\toverlap"
Sample.new.init_from_arg.count_overlap.each do |k, v|
  puts "#{k}\t#{v.round(3)}"
end

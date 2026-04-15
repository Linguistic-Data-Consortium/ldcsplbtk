#!/usr/bin/env ruby
=begin

check for final hallucinations in whisper output

    check_for_final_hallucinations.rb transcripts.tsv durations.tsv

The file durations.tsv is a two column map from filename to duration.

The durations are then used to see if hallucinations occur past that point
in the transcripts.  That is, the script filters for such final text.  For
normal data where this problem doesn't occur, the output is just a header
with no segments.

=end

require_relative '../lib/models'

raise "bad args" if ARGV.length != 2
durations = {}
File.readlines(ARGV.pop).each do |line|
  k, v = line.split
  durations[k] = v.to_f
end

Sample.new.init_from_arg.print after_time_with_map: durations

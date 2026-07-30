#!/usr/bin/env ruby
=begin

filters SCTK .pra alignment files for scored utterances, writing to stdout.

    filter_pra.rb file1.pra

Prints each alignment block -- an 'id:' line, the five lines following it,
and its 'Eval:' line -- but only where the Eval line is non-empty, i.e.
where sclite recorded at least one substitution, deletion or insertion.
Blocks that aligned perfectly are skipped.  Blocks are separated by blank
lines.

Unlike the other scripts here this one reads sclite output directly, not a
transcript, so it does not go through the Sample parsers.

=end

raise "bad args" if ARGV.length != 1
fn = ARGV[0]
string = File.read fn
string.scan(/((id:.+\n)(.+\n){5}(Eval:.*\S.*\n))/).each do |x|
  # puts ">"
  puts x[0]
  # puts "<"
  puts
  puts
end








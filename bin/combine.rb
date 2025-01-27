#!/usr/bin/env ruby
=begin

combine transcript files, check headers/columns, write to stdout

    combine.rb file1 file2 ...

The files have to have the same format.
This is essentially concatenation, but sensitive to formats and headers.
The inputs can be any format, but must be compatible.
The output is tsv.

=end

require_relative '../lib/models'

sample = Sample.new
ARGV.sort.each do |fn|
  string = File.read fn
  other_sample = Sample.new
  other_sample.init_from(string:, fn:)
  sample.add(other_sample:)
end

sample.print




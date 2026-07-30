#!/usr/bin/env ruby
=begin

counts unintelligible markers per file, writing to stdout.

    count_unintelligible.rb file1

A marker is any whitespace separated token beginning with '((', the
convention used for unintelligible speech, e.g. ((unclear)).

The output is a two column tsv of file and count:

    file    unintelligible
    interview   3

=end

require_relative '../lib/models'

puts "file\tunintelligible"
Sample.new.init_from_arg.count_unintelligible.each do |k, v|
  puts "#{k}\t#{v}"
end

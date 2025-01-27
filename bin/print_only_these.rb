#!/usr/bin/env ruby
=begin

print only the files specified in map, writing to stdout.

    print_only_these.rb map file1

=end

require_relative '../lib/models'

raise "bad args" if ARGV.length != 2
map = {}
File.readlines(ARGV.shift).each do |x|
  y = x.split
  map[y[0]] = y[1]
end

Sample.new.init_from_arg.print_only_these(map:)

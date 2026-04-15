#!/usr/bin/env ruby
=begin

converts transcript to NIST STM format, writing to stdout.

    stm.rb file1

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








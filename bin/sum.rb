#!/usr/bin/env ruby
=begin

converts transcript to NIST CTM format, writing to stdout.

    ctm.rb file1

=end

require_relative '../lib/models'

puts Sample.new.init_from_arg.sum

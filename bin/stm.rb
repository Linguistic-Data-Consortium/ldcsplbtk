#!/usr/bin/env ruby
=begin

converts transcript to NIST STM format, writing to stdout.

    stm.rb file1

=end

require_relative '../lib/models'

puts Sample.new.init_from_arg.stm

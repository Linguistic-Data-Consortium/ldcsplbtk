#!/usr/bin/env ruby
=begin

converts transcript to NIST STM format, writing to stdout.

    stm.rb file1

=end

require_relative '../lib/models'

raise "bad args" if ARGV.length != 2
dn = ARGV.pop
Sample.new.init_from_arg.rttm dn

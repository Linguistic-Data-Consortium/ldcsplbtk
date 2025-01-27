#!/usr/bin/env ruby
=begin

changes speaker names to letters a, b, c, ..., writing to stdout.

    normalize_speakers.rb file1

=end

require_relative '../lib/models'

puts Sample.new.init_from_arg.normalize_speakers

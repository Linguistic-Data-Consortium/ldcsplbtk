#!/usr/bin/env ruby
=begin

lists the distinct file ids in a transcript, writing to stdout.

    print_files.rb file1

One id per line, sorted and de-duplicated.  Useful for seeing which
transcripts a combined file covers.

=end

require_relative '../lib/models'

puts Sample.new.init_from_arg.get_files

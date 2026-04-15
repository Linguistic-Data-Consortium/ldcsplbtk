#!/usr/bin/env ruby
=begin

combine (concatenates) tsv files, check headers/columns, write to stdout

    combine.rb file1 file2 ...

The header can be specified with the first arg like this

    combine.rb h:beg:end:text file1 file2 ...

which indicates a three column format of beg, end, and text columns.

If the header isn't given, the first file must have a header.  Otherwise headers are optional,
and are discarded.  The output has a single header.

=end

require_relative '../lib/models'

puts "file\toverlap"
Sample.new.init_from_arg.count_overlap.each do |k, v|
  puts "#{k}\t#{v.round(3)}"
end

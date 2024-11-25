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

if ARGV[0] =~ /^h:(.+)/
  header = $1.gsub ":", "\t"
  fns = ARGV[1..-1]
else
  fns = ARGV
end

sample = nil
fns.sort.each do |fn|
  string = File.read fn
  if sample.nil?
    sample = if header
      Sample.new fn: fn, header: header
    else
      Sample.new fn: fn, string: string
    end
  else
    sample.add_from_string fn:, string:
  end
end

sample.puts




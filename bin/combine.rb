#!/usr/bin/env ruby
=begin

combine transcript files, check headers/columns, write to stdout

    combine.rb [options] file1 file2 ...

Options:
    --strip-ext, -s     Strip file extensions from first column (default)
    --keep-ext, -k      Keep file extensions in first column

The files have to have the same format.
This is essentially concatenation, but sensitive to formats and headers.
The inputs can be any format, but must be compatible.
The output is tsv.

=end

require_relative '../lib/models'

# Parse options
strip_extensions = true
files = []

ARGV.each do |arg|
  case arg
  when '--strip-ext', '-s'
    strip_extensions = true
  when '--keep-ext', '-k'
    strip_extensions = false
  else
    files << arg
  end
end

sample = Sample.new
files.sort.each do |fn|
  string = File.read fn
  other_sample = Sample.new
  other_sample.init_from(string:, fn:)
  sample.add(other_sample:)
end

sample.print(strip_extensions: strip_extensions)




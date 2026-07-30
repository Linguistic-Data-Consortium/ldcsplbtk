#!/usr/bin/env ruby
=begin

writes the text of a transcript, one plain text file per file id.

    text_only.rb file1 directory

The directory must already exist.  One <file-id>.txt is written into it for
each distinct file id, containing that file's segment text joined with
spaces and no timestamps.

NOTE: the normalization rules applied here (spelling out numerals, trimming
elongated letters) inspect one whole segment at a time rather than one token
at a time, so on segment level transcripts they mostly do not fire.  They
were written for word level input.

=end

require_relative '../lib/models'

raise "bad args" if ARGV.length != 2
dn = ARGV.pop
Sample.new.init_from_arg.text_only.each do |fn, text|
  # puts text.split.select { |x| x == 'xyz' }
  File.write "#{dn}/#{fn}.txt", text
end

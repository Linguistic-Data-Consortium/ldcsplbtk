#!/usr/bin/env ruby
=begin

splits a combined transcript into one tsv per file id.

    split.rb file1 directory

The directory must already exist.  One <file-id>.tsv is written into it for
each distinct file id, each carrying the same header as the input.  This is
the inverse of combine.rb.

=end

require_relative '../lib/models'

raise "bad args" if ARGV.length != 2
dn = ARGV.pop
Sample.new.init_from_arg.split dn

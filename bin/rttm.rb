#!/usr/bin/env ruby
=begin

converts transcript to NIST RTTM format, writing one file per file id.

    rttm.rb file1 directory

The directory must already exist.  One <file-id>.rttm is written into it for
each distinct file id in the transcript, so a combined transcript covering
several recordings fans back out into separate RTTMs.

Segments are grouped by speaker within each file.  Zero length segments are
given a duration of 0.001 so downstream scoring tools accept them.

=end

require_relative '../lib/models'

raise "bad args" if ARGV.length != 2
dn = ARGV.pop
Sample.new.init_from_arg.rttm dn

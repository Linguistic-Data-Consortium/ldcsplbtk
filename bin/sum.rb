#!/usr/bin/env ruby
=begin

reports speech duration against audio duration per file, writing to stdout.

    sum.rb file1

Four space separated columns:

    file  segment-sum  unique-speech  audio-duration

where segment-sum adds up every segment duration, unique-speech collapses
overlapping segments so simultaneous speech is counted once, and
audio-duration comes from the audio file itself.  Comparing the first two
shows how much overlap there is; comparing to the third shows coverage.

NOTE: the audio path is currently hardcoded to
/clinical/poetry/penn_sound_audio/data/<file>.flac and shells out to soxi,
so this script only works on that corpus, on a host with sox installed.

=end

require_relative '../lib/models'

puts Sample.new.init_from_arg.sum

#!/usr/bin/env ruby
=begin

converts passage reading json to tsv, writing to stdout.

    passage_reading.rb [options] file1.json [file2.json ...]

Options:
    --prompt-text, -p   text column is the passage as written (default)
    --asr-text, -a      text column is what the recognizer heard

Unlike the other scripts here this one does not go through the Sample
parsers, because in the default mode the two halves of each row come from
different places in the input.  The text is the *targeted* passage the
student was asked to read, verbatim from expectedText; the timestamps are
what the ASR actually heard.  Sample assumes text and timestamps describe
the same thing, so it cannot represent this.

The input is a json array with one object per passage.  Each row of output
is built from one such object:

    file    activityId
    beg     first word's start_time, from the kaldi transcription
    end     last word's end_time, likewise
    text    expectedText, or the kaldi text under --asr-text

Timing is always the recognizer's.  Only the text column changes between the
two modes, and the rows correspond one to one, so diffing the two outputs
shows exactly where the reading departed from the passage:

    passage_reading.rb    foo.json > prompt.tsv
    passage_reading.rb -a foo.json > heard.tsv
    diff prompt.tsv heard.tsv

kaldi is the only engine used.  The file also carries kaldiNa, whose
timestamps are whole second placeholders (0-1, 1-2, ...) with an identical
confidence on every word, and wav2vec, which is phonetic and has no times at
all; neither is a usable source, so neither is offered.

Times are rounded to milliseconds.  Multiple input files are concatenated in
sorted filename order under a single header, as combine.rb does.

The output is an ordinary four column transcript, so the rest of the toolkit
reads it: segment_stats.rb, merge_segments.rb, stm.rb, split.rb and so on.

The reference output this was built from named its columns Kit, Source,
Begin, End, Text, Speaker and Section.  Kit was just passageIndex + 1, and
Speaker and Section were declared in the header and then left off every row,
which made the header disagree with the rows; none of the three say anything
about a passage reading, so all three are dropped.  The remaining columns
are renamed to the file/beg/end/text this toolkit uses everywhere else.

Passage text is often laid out over several lines.  A tsv field cannot hold
that layout, so runs of whitespace -- newlines and tabs included -- collapse
to a single space, and a note goes to stderr saying how many passages in the
file were affected.

Rows are ordered by passageIndex, whatever order the array is in.  Nothing
in the output records the passage number, so row order is the only thing
carrying it, and it should come from the data rather than from however the
file happened to be serialized.  A passageIndex that is missing, not an
integer, or duplicated stops the run, since there is then nothing to order
by.  Gaps are allowed and just mean one fewer row.

=end

require 'json'

HEADER = %w[ file beg end text ].join("\t")
ENGINE = 'kaldi'
USAGE = "Usage: passage_reading.rb [--prompt-text|--asr-text] file1.json ..."

asr_text = false
files = []

ARGV.each do |arg|
  case arg
  when '--prompt-text', '-p'
    asr_text = false
  when '--asr-text', '-a'
    asr_text = true
  when /^-/
    STDERR.puts "Unknown option: #{arg}"
    STDERR.puts USAGE
    exit 1
  else
    files << arg
  end
end

if files.empty?
  STDERR.puts USAGE
  exit 1
end

missing = files.reject { |fn| File.exist? fn }
unless missing.empty?
  STDERR.puts "Error: file not found: #{missing.join ', '}"
  exit 1
end

# Times come back from the recognizer with float noise, e.g. 3.1499998569.
# Round to milliseconds, and print integral values as 21.63 rather than
# 21.63000000000001.
def format_time(x)
  x.to_f.round(3)
end

# Rows come out in passageIndex order whatever order the array is in.  No
# output column records the passage number, so row order is the only thing
# carrying it, and it should come from the data rather than from however the
# file happened to be serialized.
#
# Gaps are fine -- a missing passage just means one fewer row.  A passageIndex
# that is absent or not an integer is not, since there is then nothing to sort
# by, and neither are duplicates, which would make the order among them
# arbitrary.
def sort_by_passage_index(passages, fn:)
  passages.each_with_index do |passage, position|
    index = passage['passageIndex']
    unless index.is_a? Integer
      raise "#{fn}: passage at position #{position} has passageIndex " \
            "#{index.inspect}, expected an integer"
    end
  end

  indexes = passages.map { |p| p['passageIndex'] }
  duplicated = indexes.tally.select { |_, n| n > 1 }.keys.sort
  unless duplicated.empty?
    raise "#{fn}: duplicate passageIndex #{duplicated.join ', '}"
  end

  passages.sort_by { |p| p['passageIndex'] }
end

# Text goes into a single tsv field, so internal whitespace has to collapse:
# a tab would split the row and a newline would truncate it, corrupting every
# column after.  A passage laid out over several lines cannot keep that layout
# in this format whatever we do, so collapse runs of whitespace to one space
# rather than refusing the file.
def flatten_text(text)
  text.to_s.gsub(/\s+/, ' ').strip
end

def rows_from(object, fn:, asr_text:)
  unless object.is_a? Array
    raise "#{fn}: expected a json array of passages, got #{object.class}"
  end

  flattened = 0

  rows = sort_by_passage_index(object, fn:).filter_map do |passage|
    index = passage['passageIndex']
    asr = passage[ENGINE]

    # A passage the recognizer never returned for is skipped with a warning
    # rather than emitted with blank or zero times, which would read as a
    # real measurement of zero.
    if asr.nil?
      STDERR.puts "#{fn}: passage #{index}: no #{ENGINE} result, skipping"
      next
    end

    words = asr['transcription']
    if words.nil? || words.empty?
      STDERR.puts "#{fn}: passage #{index}: empty #{ENGINE} transcription, skipping"
      next
    end

    # Missing times would otherwise coerce to 0.0 and report the passage as
    # spanning 0.0 to 0.0, which reads as a real measurement.
    if words.first['start_time'].nil? || words.last['end_time'].nil?
      STDERR.puts "#{fn}: passage #{index}: #{ENGINE} has no timestamps, skipping"
      next
    end

    raw = asr_text ? asr['text'] : passage['expectedText']
    field = asr_text ? "#{ENGINE} text" : 'expectedText'
    text = flatten_text(raw)
    flattened += 1 if text != raw.to_s.strip

    if text.empty?
      STDERR.puts "#{fn}: passage #{index}: empty #{field}, skipping"
      next
    end

    [
      passage['activityId'],
      format_time(words.first['start_time']),
      format_time(words.last['end_time']),
      text
    ].join("\t")
  end

  # Say so once per file rather than once per passage.  This is a change to
  # the data, even if an unavoidable one, so it should not be silent.
  if flattened > 0
    STDERR.puts "#{fn}: collapsed internal whitespace in #{flattened} passage(s)"
  end

  rows
end

rows = files.sort.flat_map do |fn|
  begin
    object = JSON.parse File.read fn
  rescue JSON::ParserError => e
    STDERR.puts "Error: #{fn}: not valid json: #{e.message.lines.first.strip}"
    exit 1
  end

  begin
    rows_from(object, fn:, asr_text:)
  rescue RuntimeError => e
    STDERR.puts "Error: #{e.message}"
    exit 1
  end
end

# Parse everything before writing anything, so a bad file part way through a
# batch fails without having already emitted a partial tsv to stdout.
puts HEADER
puts rows unless rows.empty?

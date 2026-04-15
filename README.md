# LDC Speech Label Toolkit

Code for manipulating text based speech labels, including transcripts.

# Examples

Consider this file, called `hamlet.tsv`:

    file    beg end text
    hamlet.wav  1.1 2.2 to be
    hamlet.wav  3.3 4.4 or not to be

This is a plain text, tab delimited (TSV), four column file, with a header
and two transcribed segments.  In general, this library reads and writes tabular
data like this.  A wide variety of input formats can be parsed, but not necessarily used as output formats.

Consider another file, called `lincoln.tsv`

    file    beg end text
    lincoln.wav 80.0 81.0 four score
    lincoln.wav 82.0 87.0 and seven years ago

The command

    bin/combine.rb hamlet.tsv lincoln.tsv > hamlin.tsv

would produce a file `hamlin.tsv` like this (note: file extensions are stripped by default):

    file    beg end text
    hamlet.wav  1.1 2.2 to be
    hamlet.wav  3.3 4.4 or not to be
    lincoln.wav 80.0 81.0 four score
    lincoln.wav 82.0 87.0 and seven years ago

This file represents two different transcripts, but can they can be manipulated
together, which reduces the number of files users have to deal with.

# Concatenation and Conversion

The `combine.rb` script is similar to the `cat` command in that it concatenates its arguments, but it's also format sensitive.  The file `hamlin.tsv` is essentially a concatenation of two transcripts, but the header only appears once.  The script parses and converts its input, so you might do

    bin/combine.rb foo.json > foo.tsv

to convert some other format to TSV.  But conversion is always to TSV, not anything else.  The command

    bin/combine.rb hamlin.tsv > hamlin.json

just produces an identical TSV, not a json file.  The file extension is ignored by `combine.rb`, unlike, for example, `sox`.  The general purpose of `combine.rb` is to combine multiple transcripts into a consolidated file to simplify further processing.  The output is logically the following:

    <header>
    <transcript1>
    <transcript2>
    ...

where the ordering of the transcripts is based on the sorted order of the argument filenames, not the filenames inside the transcripts.  So these commands:

    bin/combine.rb hamlet.tsv lincoln.tsv
    bin/combine.rb lincoln.tsv hamlet.tsv
    bin/combine.rb *.tsv

would produce identical output (assuming only two inputs).  This produces consistent output without sorting the transcript segments themselves which might be undesirable.  Finally, the inputs can be different formats, but they must be consistent, where consistency here means having the same fields.  For example, combining TSVs that have a different number of columns will fail, even if they might seem compatible.  This is a safeguard against combining transcripts that are truly incompatible by accident; the user must take extra steps to create consistency.

## File Extension Handling

By default, `combine.rb` strips file extensions from the first column. You can control this behavior with command-line flags:

```bash
# Strip extensions (default behavior)
bin/combine.rb hamlet.tsv lincoln.tsv > hamlin.tsv
bin/combine.rb --strip-ext hamlet.tsv lincoln.tsv > hamlin.tsv

# Keep extensions
bin/combine.rb --keep-ext hamlet.tsv lincoln.tsv > hamlin.tsv
bin/combine.rb -k hamlet.tsv lincoln.tsv > hamlin.tsv
```

## Segment Statistics

The `segment_stats.rb` script calculates statistics about segment durations and gaps:

```bash
bin/segment_stats.rb transcript.tsv
```

Output includes per-file statistics:
- **segments**: Number of segments
- **avg_length**: Average segment duration in seconds
- **avg_gap**: Average gap between consecutive segments in seconds
- **total_length**: Total duration of all segments in seconds

Example output:
```
file          segments  avg_length  avg_gap  total_length
interview.wav 3         1.667       0.0      5.0
```

Gaps are calculated between consecutive segments (sorted by begin time). Overlapping segments result in negative gaps, which are excluded from the average.

## Segment Merging

The `merge_segments.rb` script merges consecutive transcript segments when the gap between them is below a specified threshold:

```bash
# Merge segments with gaps less than 0.5 seconds
bin/merge_segments.rb 0.5 transcript.tsv > merged.tsv

# Merge segments with gaps less than 1.0 seconds
bin/merge_segments.rb 1.0 input.json > merged.tsv
```

Behavior:
- **Merges consecutive segments** within the same file when gap < threshold
- **Preserves speaker boundaries** - only merges segments with the same speaker
- **Does NOT merge across different source files** - each file is processed independently
- Segments are sorted by begin time before merging
- Merged segments combine their text with spaces

Example:
```
# Input with small gaps
file          beg  end  text
interview.wav 0.0  1.0  hello
interview.wav 1.2  2.0  world
interview.wav 5.0  6.0  test

# Output with threshold 0.5 (gap 0.2 < 0.5, gap 3.0 >= 0.5)
file          beg  end  text
interview.wav 0.0  2.0  hello world
interview.wav 5.0  6.0  test
```

# Testing

The toolkit includes a comprehensive test suite using Minitest. To run the tests:

```bash
rake test
```

The test suite includes:
- **Unit tests** for the `Sample` class (44 tests, 224 assertions)
- **Integration tests** for command-line scripts (17 tests, 48 assertions)
- **Comprehensive format coverage:**
  - TSV (basic, with speaker, with section)
  - CTM (NIST format)
  - JSON formats: Whisper, Whisper.cpp, Rev.ai, Google Cloud v1 & v2, IBM Watson, Azure
- Utility method tests (unintelligible counting, speaker normalization, overlap detection, segment merging, etc.)

See `test/README.md` for detailed testing documentation.


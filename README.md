# LDC Speech Label Toolkit

Code for manipulating text based speech labels, including transcripts.

A wide variety of input formats can be parsed -- tab delimited text, NIST CTM,
and the JSON emitted by most commercial ASR services -- and all of them are
normalized to one tabular representation. Most scripts read that
representation, do one thing to it, and write to stdout.

# Requirements

- **Ruby 3.1 or later.** The code uses shorthand hash syntax (`foo(bar:)`),
  which is a syntax error on Ruby 3.0.
- **No gems.** The only dependency is `json` from the standard library.
  Minitest, used by the test suite, also ships with Ruby.
- **`sox`** is needed by `sum.rb` only, which shells out to `soxi` to read
  audio durations. Every other script works without it.

There is nothing to install or build. Clone the repository and run the
scripts out of `bin/`, which are executable and carry a shebang:

    git clone <repository-url>
    cd ldcsplbtk
    bin/combine.rb transcript.tsv

Add `bin/` to your `PATH` if you would rather not type the prefix.

# The tabular format

Consider this file, called `hamlet.tsv`:

    file    beg end text
    hamlet.wav  1.1 2.2 to be
    hamlet.wav  3.3 4.4 or not to be

This is a plain text, tab delimited (TSV), four column file, with a header
and two transcribed segments. In general, this library reads and writes
tabular data like this. A wide variety of input formats can be parsed, but
not necessarily used as output formats.

`beg` and `end` are seconds from the start of the recording. Two further
columns are optional and must appear in this order:

    file    beg end text    speaker
    file    beg end text    speaker section

A segment is one row. Depending on the source it may be a word, an utterance,
or a whole recording -- nothing in the format distinguishes these.

Consider another file, called `lincoln.tsv`

    file    beg end text
    lincoln.wav 80.0 81.0 four score
    lincoln.wav 82.0 87.0 and seven years ago

The command

    bin/combine.rb hamlet.tsv lincoln.tsv > hamlin.tsv

would produce a file `hamlin.tsv` like this (note: file extensions are stripped by default):

    file    beg end text
    hamlet  1.1 2.2 to be
    hamlet  3.3 4.4 or not to be
    lincoln 80.0 81.0 four score
    lincoln 82.0 87.0 and seven years ago

This file represents two different transcripts, but they can be manipulated
together, which reduces the number of files users have to deal with.

# Input formats

Format detection is automatic, based on content rather than file extension.

| Format | Notes |
|---|---|
| TSV, 4/5/6 column | With or without a header row |
| TSV, `start end text` header | No file column; supply the name (see below) |
| TSV, 3 column speech activity | `beg`, `end`, and `speech` or `non-speech` |
| CTM | NIST Conversation Time Marked |
| Rev.ai JSON | word level, with speaker |
| Whisper JSON | word level if `words` present, otherwise timings are interpolated evenly across the segment's words |
| Whisper.cpp JSON | segment level |
| Google Cloud STT JSON | v1 and v2, with speaker |
| AWS Transcribe JSON | with speaker or channel where present |
| IBM Watson JSON | with speaker |
| Microsoft Azure JSON | with speaker |

The two formats that carry no file column take it from the input filename.
That is supplied automatically by the scripts; against the library directly
it is the `fn:` argument, and omitting it raises `the file name must be set`:

```ruby
Sample.new.init_from(string: File.read('sad.tsv'), fn: 'interview.wav')
```

The same applies to every JSON format, none of which record the name of the
audio they describe. For those the file column is the basename of the input
file, so `rev.json` yields a file id of `rev` once extensions are stripped.

Output is TSV, or one of the conversion formats below. Round tripping is not
a goal: the parsers are lossy, and information a format does not have a
column for is dropped.

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

Leading directories are always stripped, whichever flag is used.

# The scripts

Every script takes exactly the arguments shown. None of them read stdin, and
none accept `--help`; the comment at the top of each file is its
documentation.

## Converting

| Script | Usage | Purpose |
|---|---|---|
| `combine.rb` | `[options] file...` | Concatenate and convert to TSV |
| `stm.rb` | `file` | Convert to NIST STM |
| `ctm.rb` | `file` | Convert to NIST CTM, splitting segments into words |
| `rttm.rb` | `file dir` | Convert to NIST RTTM, one file per file id |
| `split.rb` | `file dir` | Split into one TSV per file id (inverse of `combine.rb`) |
| `text_only.rb` | `file dir` | Write plain text, one file per file id |

## Measuring

| Script | Usage | Purpose |
|---|---|---|
| `segment_stats.rb` | `[--combined] file` | Segment count, mean length, mean gap, total length |
| `count_overlap.rb` | `file` | Total overlapping speech duration per file |
| `count_unintelligible.rb` | `file` | Count of `((...))` markers per file |
| `sum.rb` | `file` | Speech duration against audio duration (see caveat below) |
| `print_files.rb` | `file` | The distinct file ids in a transcript |

## Editing and filtering

| Script | Usage | Purpose |
|---|---|---|
| `merge_segments.rb` | `threshold file` | Merge consecutive segments across small gaps |
| `normalize_speakers.rb` | `file` | Rewrite speaker labels as `a`, `b`, `c`, ... |
| `print_only_these.rb` | `map file` | Keep only the file ids listed in a two column map |
| `check_for_final_hallucination.rb` | `file durations` | Find segments past a recording's known duration |

## Scoring output

These two read SCTK output rather than transcripts, and do not go through
the parsers.

| Script | Usage | Purpose |
|---|---|---|
| `wer_from_sys.rb` | `file.sys...` | Extract word error rate from `.sys` files |
| `filter_pra.rb` | `file.pra` | Show only alignment blocks that scored an error |

**Caveat on `sum.rb`:** it resolves audio as
`/clinical/poetry/penn_sound_audio/data/<file>.flac`, a hardcoded path, so it
only works on that corpus. The same hardcoding affects the `pred_text` JSON
parser.

## Segment Statistics

The `segment_stats.rb` script calculates statistics about segment durations and gaps:

```bash
# Per-file statistics (default)
bin/segment_stats.rb transcript.tsv

# Combined statistics (treat all segments as single document)
bin/segment_stats.rb --combined transcript.tsv
bin/segment_stats.rb -c transcript.tsv
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

With `--combined` flag, statistics are calculated across all segments:
```
file          segments  avg_length  avg_gap  total_length
combined      8         1.450       0.325    11.6
```

In combined mode, segment lengths are averaged across all segments, and gaps are averaged across all gaps (gaps are still calculated within each file, not across file boundaries). Overlapping segments result in negative gaps, which are excluded from the average.

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
- A merged segment spans to the latest end time of its inputs, so nesting a
  short segment inside a longer one does not shorten the result

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

# Using the library directly

The scripts are thin wrappers over one class, `Sample`, in `lib/models.rb`:

```ruby
require_relative 'lib/models'

sample = Sample.new
sample.init_from(string: File.read('transcript.tsv'))

sample.print          # write TSV to stdout
puts sample.stm       # convert to STM
sample.segments       # array of hashes, keyed :file, :beg, :end, :text, ...
```

`add(other_sample:)` merges another `Sample` in, and raises unless the two
have identical headers. `print` does not modify the sample, so it can be
called more than once.

# Testing

The toolkit includes a test suite using Minitest. To run the tests:

```bash
rake test
```

The suite covers every input format listed above, the conversion outputs, the
utility methods, and each `bin/` script end to end. `test/test_known_bugs.rb`
holds regression tests for previously fixed defects, named for the behavior
they pin down.

See `test/README.md` for detailed testing documentation.

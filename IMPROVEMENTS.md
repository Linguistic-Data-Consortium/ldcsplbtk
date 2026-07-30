# Open Improvements

Work identified in review and not yet done. Items that have been completed
are recorded in `CHANGELOG.md` rather than kept here, so this file should
only ever shrink or gain genuinely new entries.

Line numbers refer to `lib/models.rb` and drift with edits; treat them as
hints, not addresses.

## Correctness and safety

### Hardcoded paths and shell injection (`:440`, `:790`, `bin/wer_from_sys.rb:11`)

```ruby
duration = `soxi -D /clinical/poetry/#{filename}`.to_f
d = `soxi -D /clinical/poetry/penn_sound_audio/data/#{k}.flac`.chomp.to_f
a = `grep Sum #{fn}`.split
```

Two problems in each. The corpus path is baked in, so `sum.rb` and the
`pred_text` parser only work on one machine. And the interpolated value is
neither escaped nor validated, so a filename containing shell metacharacters
executes arbitrary commands.

Take the base path from an environment variable or flag, and use the array
form so no shell is involved:

```ruby
duration = IO.popen(['soxi', '-D', File.join(base_path, filename)], &:read).to_f
```

### `find_ibm_speaker` aborts the parse on any imperfect match (`:452`)

It raises unless exactly one speaker label strictly contains the word's time
span. Real Watson output routinely violates that, and a single unmatched
word kills the whole file. Prefer the label with the greatest overlap, and
warn rather than raise. It is also O(n²): a `select` over every label, per
word.

### Speaker letters are shared across files (`:611`)

```ruby
spk = '`'.dup unless map[y[:file]]
```

`spk` resets only the first time a file is seen, so with interleaved files
the second file continues the first's sequence -- `a, b` then `c, d` rather
than `a, b` and `a, b` again. Reset per file. `change_speakers` (`:593`)
duplicates this logic and differs only in printing instead of returning.

### Float formatting (`:521`)

`segment2line` writes raw floats, so any computed time can surface as
`2.9000000000000004`. The parsers round inconsistently -- Azure and
Whisper.cpp round to three places, CTM's `end += beg` does not. Round once,
at output, and drop the scattered `.round(3)` calls.

## Performance

### `sum` materializes one array element per millisecond (`:786`)

```ruby
slices[x[:file]] << (b...e).to_a
```

An hour of audio is about 3.6 million integers per file, then `flatten.uniq`
over all of them. Sort the intervals and merge them in one pass instead.

### `count_overlap` is O(n²) (`:849`)

Every segment is compared against every earlier segment in the same file.
Correct since the identity fix, but a sweep over start-sorted intervals
would make it O(n log n).

## Dead code

- `print_find` (`:624`), `print_findx` (`:635`), `speakersx` (`:658`) and
  `change_speakers` (`:593`) have no references in `bin/` or `test/`.
- `attr_accessor :durations` (`:43`) is never assigned anywhere, so
  `print_findx` would raise `NoMethodError` on nil the moment it ran.
- `printone` (`:505`) works correctly now but is still unreachable from
  `bin/`. Either wire it to a script or delete it, along with its tests.
- An unused `encoding_options` hash sits in `fix_parens` (`:541`).

Deleting these is the cheapest way to shrink the class. `git` remembers them.

## `text_only` does not do what it appears to (`:710`)

```ruby
files[x[:file]] << x[:text]   # whole segment text
a = text.map do |token|       # ...treated as one token
```

The `case` matches against an entire segment string, so on segment level
input none of the rules fire. The rules themselves are corpus specific
(`'1974'`, `'120'`, `rrrrrrrrrr+`) and belong in a script, not the library.
`num` (`:750`) returns `nil` for any non-digit character, so `$50` would
render as `" five zero dollars"` if it ever matched.

Decide whether this is a general normalizer or a corpus tool, and move or
rewrite it accordingly.

## Packaging

- **`lib/models.rb` is a load-path landmine.** `require "models"` from a
  shared `-Ilib` is about as generic as a name can get. Move to
  `lib/ldcsplbtk/sample.rb` with a `lib/ldcsplbtk.rb` entry point.
- **Nothing declares the Ruby floor.** The code needs 3.1 for shorthand hash
  syntax and fails on 3.0 with a confusing syntax error. Add a
  `.ruby-version`, and a gemspec or Gemfile.
- **No CI.** Running `rake test` on push is a short workflow file, and would
  have caught two of the ten defects fixed so far.
- **`Rakefile:8` sets `t.warning = false`,** which is why `ruby -w` warnings
  never surface in a test run.

## Command line consistency

`combine.rb` and `segment_stats.rb` hand-roll flag parsing; the rest use
positional `ARGV` with a bare `raise "bad args"`. No script accepts
`--help` or `--version`, and none reads stdin, so nothing composes into a
pipeline. Standardizing on `OptionParser`, adding stdin support, and
replacing `raise` with a message on stderr plus a non-zero exit would make
this a toolkit rather than a set of one-offs.

## Validation

`add_segment_from_tsv` coerces timestamps with `to_f`, which turns any
unparseable value into `0.0` without complaint:

```ruby
when 'beg', 'end'
  v = Float(v) rescue raise("Invalid timestamp '#{v}' in line: #{line}")
```

A `Sample#valid?` covering the obvious invariants -- non-negative times,
`end >= beg`, required fields present -- would catch bad input at the door
rather than several transformations later.

# Changelog

Notable changes to the LDC Speech Label Toolkit.

The project is not versioned and has no releases, so everything below sits
under Unreleased, newest group first. Once versions exist, cut a dated
section here and leave Unreleased for what follows it.

## Unreleased

### Fixed

Ten defects found in review. Each has a regression test in
`test/test_known_bugs.rb`, written to fail against the unfixed code.

Wrong output, produced silently:

- **Whisper segment-level parsing corrupted the preceding segment.** A
  segment whose text was empty rewrote the end time of a word belonging to
  the *previous* segment, and divided by zero computing its own word
  timings. Wordless segments are now skipped.
- **Merging a nested segment discarded audio.** `merge_segments` assigned
  rather than extended the merged end time, so a short segment inside a
  longer one moved the end backwards. A merged span now covers the latest
  end time of its inputs.
- **Short CTM lines parsed into nil fields.** The column check compared a
  four element slice against a four column header, so it was always true.
  The source line is now validated before slicing.
- **Overlapping duplicate segments went uncounted.** `count_overlap` used
  hash value equality to skip self-comparison, so two distinct segments with
  identical fields were treated as the same segment. It now compares
  identity.

Crashes and formats that never worked:

- **A file missing from a durations map crashed** `check_for_final_hallucination.rb`
  with `comparison of Float with nil failed`. Files with no known duration
  are now skipped, since nothing about them can be reported.
- **Two documented input formats had never parsed.** Both the
  `start end text` header and the three column speech activity form set a
  four column header for three column data, so every row raised
  `bad line, 3 columns`. Both now take the file column from the input
  filename.
- **JSON input failed in ten scripts.** `init_from_arg` never passed the
  filename through, so every vendor JSON parser raised
  `Filename must be set`. It now passes the basename -- not the full path,
  which `split.rb` and `rttm.rb` interpolate into output filenames.

Malformed or surprising output:

- **STM output emitted an empty speaker field** for input without a speaker
  column, producing invalid NIST STM. It now falls back to `unknown`.
- **`print` mutated the sample it rendered**, so the first call stripped
  extensions permanently and a later `strip_extensions: false` had nothing
  left to preserve. It now renders into copies.
- **`printone` discarded every argument it accepted**, passing hardcoded
  values to `print_prep` instead of `norm:`, `after_time:` and
  `after_time_with_map:`.

### Documentation

- Corrected the header comment on eight scripts that documented a different
  script entirely -- `count_overlap.rb` and `count_unintelligible.rb`
  described `combine.rb`, and `filter_pra.rb`, `print_files.rb`, `rttm.rb`,
  `split.rb`, `sum.rb` and `text_only.rb` described `stm.rb` or `ctm.rb`.
  These comments are each script's only usage documentation.
- Rewrote `README.md`: added requirements, the Ruby 3.1 floor, installation,
  a table of every input format, and a table covering all seventeen scripts
  rather than five. Corrected the `combine.rb` example, which showed
  unstripped filenames while stating extensions are stripped by default.
- Documented that `sum.rb` and the `pred_text` parser resolve audio through
  a hardcoded corpus path and only work on that corpus.
- `test/README.md` no longer describes Google Cloud v1 as both broken and
  fixed, and no longer cites test counts that drift out of date.

### Added

- **`merge_segments.rb`** -- merge consecutive segments when the gap between
  them is below a threshold. Merges within a file only, and only across
  matching speakers. Adds `Sample#merge_segments(threshold:)`.
- **`segment_stats.rb`** -- segment count, mean length, mean gap and total
  length, per file or, with `--combined` / `-c`, across all segments. Gaps
  are still measured within a file, never across file boundaries. Adds
  `Sample#average_segment_length`, `#average_segment_gap` and
  `#segment_statistics(combined:)`.
- **Extension flags for `combine.rb`** -- `--strip-ext` / `-s` (the existing
  default) and `--keep-ext` / `-k`.

### Changed

- **Google Cloud v1 parsing works.** The v1 parser had been unreachable: v2
  matched every object with a `results` key first. The two are now
  distinguished by timestamp shape -- v1 uses `{seconds, nanos}` objects, v2
  uses `"1.5s"` strings.
- **Split `add_object` into per-vendor parsers.** One 204 line method with
  eight levels of nesting became thirteen focused ones, one per format plus
  dispatchers for the Google Cloud and Whisper variants.
- Replaced placeholder errors such as `what to do?` with messages naming the
  format and the offending value.
- Renamed opaque helpers: `ibmsp` to `find_ibm_speaker`, `gcts` to
  `google_cloud_timestamp`, `gctsv2` to `google_cloud_v2_timestamp`.
- Extracted magic numbers into named constants: `SPEECH_DURATION_THRESHOLD`,
  `DEFAULT_SPEAKER`, `CTM_MIN_COLUMNS`.
- Removed roughly eighty lines of commented-out code.
- Added class and method documentation to `Sample`.
- Resolved frozen string literal mutation warnings in `normalize_speakers`
  and `change_speakers`.

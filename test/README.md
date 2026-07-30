# Test Suite for LDC Speech Label Toolkit

This directory contains the test suite for the LDC Speech Label Toolkit.

The suite uses **Minitest**, which ships with Ruby, so there are no
dependencies to install. Ruby 3.1 or later is required, matching the library
itself.

## Running Tests

### Run all tests
```bash
rake test
```

or directly with Ruby:
```bash
ruby -Ilib:test test/test_sample.rb
ruby -Ilib:test test/test_bin_scripts.rb
```

### Run with verbose output
```bash
rake test_verbose
```

### Run a specific test file
```bash
rake test_file[test/test_sample.rb]
```

### Run a specific test method
```bash
ruby -Ilib:test test/test_sample.rb -n test_init_from_basic_tsv
```

## Test Structure

### test_sample.rb
Unit tests for the `Sample` class covering:
- Initialization and header management
- TSV format parsing (basic, with speaker, with section)
- CTM format parsing
- JSON format parsing for every supported vendor
- Combining samples
- Output format generation (STM, CTM)
- Utility methods (count_unintelligible, normalize_speakers, etc.)
- Edge cases and error handling

### test_bin_scripts.rb
Integration tests for the command-line scripts in `bin/`:
- combine.rb
- stm.rb
- ctm.rb
- count_unintelligible.rb
- count_overlap.rb
- normalize_speakers.rb
- split.rb
- text_only.rb
- print_files.rb
- segment_stats.rb
- merge_segments.rb

### test_segment_stats.rb
Unit tests for segment statistics functionality:
- average_segment_length
- average_segment_gap
- segment_statistics (comprehensive stats, per-file mode)
- segment_statistics with combined mode (calculate averages across all segments, gaps within file boundaries)
- Edge cases (single segment, overlapping segments, multiple files, empty sample)

### test_merge_segments.rb
Unit tests for segment merging functionality:
- Basic merging with various thresholds
- Threshold boundary conditions
- Multi-file handling (no cross-file merging)
- Speaker diarization (no cross-speaker merging)
- Edge cases (single segment, empty sample, zero threshold)
- Partial merging scenarios
- Header preservation
- Complex multi-file, multi-speaker scenarios

### test_combine_options.rb
Tests for combine.rb command-line options:
- --strip-ext / -s flag
- --keep-ext / -k flag
- Multiple file handling with options

### test_known_bugs.rb
Regression tests for defects found in review and since fixed. Each test is
named for the behavior it pins down and carries a comment giving the
original failure. These were written to fail first, against the unfixed
code, so each one demonstrably exercises the defect rather than merely
passing alongside it.

Covered there:
- Whisper segment-level parsing no longer rewrites the previous segment's
  end time when a segment has empty text
- Merging a nested segment does not shorten the merged span
- Short CTM lines are rejected rather than parsed into nil fields
- Overlap counting distinguishes duplicate segments from self-comparison
- An unknown file in a durations map is skipped rather than crashing
- The `start end text` and 3-column speech activity formats parse
- JSON input works through the scripts that load their input via
  `init_from_arg`, and the file column carries no directory prefix
- STM output never emits an empty speaker field
- `print` does not mutate the sample it renders
- `printone` honors the arguments it accepts

Two of these encode a policy decision rather than a self-evident fix, and
say so in a comment: what to do with a file absent from a durations map, and
what to emit for a missing speaker. Changing the policy means changing those
assertions.

### fixtures/
Sample data files used for testing:

**TSV/CTM formats:**
- `basic.tsv` - Simple 4-column TSV
- `speaker.tsv` - TSV with speaker column
- `section.tsv` - TSV with speaker and section columns
- `gaps.tsv` - Multi-file TSV with gaps between segments
- `basic.ctm` - CTM format sample
- `unintelligible.tsv` - TSV with unintelligible markers

**JSON formats (ASR vendor outputs):**
- `whisper.json` - Whisper format (with word-level timestamps)
- `whisper_cpp.json` - Whisper.cpp format
- `rev.json` - Rev.ai format
- `google_cloud_v1.json` - Google Cloud Speech-to-Text v1
- `google_cloud_v2.json` - Google Cloud Speech-to-Text v2
- `ibm_watson.json` - IBM Watson format
- `aws.json` - AWS Transcribe format
- `azure.json` - Microsoft Azure format

## Coverage

The suite covers:
- Core functionality of the `Sample` class
- Every input format the library claims to support:
  - **TSV** (basic, with speaker, with section columns)
  - **CTM** (NIST format)
  - **JSON**: Whisper, Whisper.cpp, Rev.ai, Google Cloud v1 and v2,
    AWS Transcribe, IBM Watson, Microsoft Azure
- Format conversions (STM, CTM output)
- Utility methods (count_unintelligible, count_overlap, normalize_speakers)
- Error handling and edge cases
- Command-line script integration

Deliberate gaps, worth knowing before trusting a green run:
- `sum.rb` and the `pred_text` parser shell out to `soxi` against a
  hardcoded corpus path, so neither is exercised
- `print_find`, `print_findx`, `speakersx` and `change_speakers` are
  untested, and are also unreachable from `bin/`

## Adding New Tests

1. Add test fixtures to `test/fixtures/` if needed
2. Add test methods to the appropriate test file:
   - Unit tests → `test_sample.rb`
   - Integration tests → `test_bin_scripts.rb`
   - Regression tests for a fixed defect → `test_known_bugs.rb`
3. Follow the naming convention: `test_<description>`
4. Run tests to verify they pass

When fixing a defect, write the test first and watch it fail. A regression
test that has never failed has not been shown to test anything.

## Test Conventions

- Use descriptive test names
- Each test should test one specific behavior
- Use assertions that clearly show what's being tested
- Clean up any temporary files created during tests
- Use fixtures from `test/fixtures/` directory

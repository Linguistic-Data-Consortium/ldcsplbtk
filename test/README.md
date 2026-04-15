# Test Suite for LDC Speech Label Toolkit

This directory contains the test suite for the LDC Speech Label Toolkit.

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
- JSON format parsing (Whisper, Rev)
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

### test_segment_stats.rb
Unit tests for segment statistics functionality:
- average_segment_length
- average_segment_gap
- segment_statistics (comprehensive stats)
- Edge cases (single segment, overlapping segments, multiple files)

### test_combine_options.rb
Tests for combine.rb command-line options:
- --strip-ext / -s flag
- --keep-ext / -k flag
- Multiple file handling with options

### fixtures/
Sample data files used for testing:

**TSV/CTM formats:**
- `basic.tsv` - Simple 4-column TSV
- `speaker.tsv` - TSV with speaker column
- `section.tsv` - TSV with speaker and section columns
- `basic.ctm` - CTM format sample
- `unintelligible.tsv` - TSV with unintelligible markers

**JSON formats (ASR vendor outputs):**
- `whisper.json` - Whisper format (with word-level timestamps)
- `whisper_cpp.json` - Whisper.cpp format
- `rev.json` - Rev.ai format
- `google_cloud_v1.json` - Google Cloud Speech-to-Text v1 (⚠️ currently broken - see below)
- `google_cloud_v2.json` - Google Cloud Speech-to-Text v2
- `ibm_watson.json` - IBM Watson format
- `azure.json` - Microsoft Azure format

## Test Framework

The test suite uses **Minitest**, which is part of Ruby's standard library (no additional dependencies required).

## Coverage

The test suite covers:
- ✅ Core functionality of the Sample class
- ✅ Multiple input formats:
  - **TSV** (basic, with speaker, with section columns)
  - **CTM** (NIST format)
  - **JSON formats:**
    - Whisper (word-level)
    - Whisper.cpp
    - Rev.ai
    - Google Cloud Speech-to-Text v1 ✅ (recently fixed!)
    - Google Cloud Speech-to-Text v2 ✅
    - IBM Watson ✅
    - Microsoft Azure ✅
- ✅ Format conversions (STM, CTM output)
- ✅ Utility methods (count_unintelligible, count_overlap, normalize_speakers)
- ✅ Error handling and edge cases
- ✅ Command-line script integration

## Recent Fixes

### Google Cloud Speech-to-Text v1 Format (Fixed!)
The Google Cloud v1 parser was previously unreachable due to a bug in the format detection logic. This has been **fixed** by implementing proper format detection that distinguishes v1 from v2:
- v1 format uses `startTime`/`endTime` as Hash objects with `seconds` and `nanos` fields
- v2 format uses `startOffset`/`endOffset` as String values (e.g., "1.5s")

The parser now correctly handles both formats. Test `test_init_from_google_cloud_v1_json` validates the fix.

## Adding New Tests

1. Add test fixtures to `test/fixtures/` if needed
2. Add test methods to the appropriate test file:
   - Unit tests → `test_sample.rb`
   - Integration tests → `test_bin_scripts.rb`
3. Follow the naming convention: `test_<description>`
4. Run tests to verify they pass

## Test Conventions

- Use descriptive test names
- Each test should test one specific behavior
- Use assertions that clearly show what's being tested
- Clean up any temporary files created during tests
- Use fixtures from `test/fixtures/` directory

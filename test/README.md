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
    - Google Cloud Speech-to-Text v2 ✅
    - IBM Watson ✅
    - Microsoft Azure ✅
    - Google Cloud v1 ⚠️ (broken - see Known Issues)
- ✅ Format conversions (STM, CTM output)
- ✅ Utility methods (count_unintelligible, count_overlap, normalize_speakers)
- ✅ Error handling and edge cases
- ✅ Command-line script integration

## Known Issues

### Google Cloud Speech-to-Text v1 Format
The Google Cloud v1 parser (lib/models.rb:217-238) is currently **unreachable** due to a bug in the format detection logic. The v2 parser (line 198) catches all objects with a 'results' key first, preventing v1 from ever being parsed correctly.

When v1 format data is provided, it gets incorrectly parsed by the v2 parser, resulting in:
- All timestamps become 0.0 (because v1 uses `startTime`/`endTime` objects, but v2 looks for `startOffset`/`endOffset` strings)
- Speaker information is lost (nil instead of proper speaker tags)

Test `test_init_from_google_cloud_v1_json_currently_broken` documents this behavior.

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

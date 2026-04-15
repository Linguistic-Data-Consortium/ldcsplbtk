# Changelog

## New Features

### Segment Statistics Script
- **Added `segment_stats.rb`** - Calculate statistics about segment durations and gaps:
  - Average segment length
  - Average gap between consecutive segments
  - Total number of segments
  - Total duration of all segments
- Added 3 new methods to `Sample` class:
  - `average_segment_length()` - Per-file average segment duration
  - `average_segment_gap()` - Per-file average gap between segments
  - `segment_statistics()` - Comprehensive stats (combines all metrics)
- Added 7 new tests (6 unit tests + 1 integration test)
- Handles multiple files, overlapping segments, and edge cases

### File Extension Control in combine.rb
- **Added command-line flags** to control file extension handling in `combine.rb`:
  - `--strip-ext` / `-s`: Strip file extensions from first column (default behavior)
  - `--keep-ext` / `-k`: Keep file extensions in first column
- Maintains backward compatibility (extensions still stripped by default)
- Added 6 new tests to verify flag behavior

## Improvements (Current)

### Critical Bug Fixes
- **Fixed Google Cloud v1 Parser** - The v1 parser was unreachable because v2 parser caught all `results` objects first. Now properly detects v1 vs v2 by examining timestamp format.
- **Fixed String Literal Warning** - Resolved frozen string literal mutation warnings in `normalize_speakers` and `change_speakers` methods.

### Major Refactoring
- **Extracted Parser Methods** - Broke down the 204-line `add_object` method into 13 focused parser methods:
  - `parse_rev()` - Rev.ai format
  - `parse_ibm()` - IBM Watson format
  - `parse_google_cloud()` - Dispatcher for Google Cloud formats
  - `parse_google_cloud_v1()` - Google Cloud v1 format
  - `parse_google_cloud_v2()` - Google Cloud v2 format
  - `parse_azure()` - Microsoft Azure format
  - `parse_whisper()` - Whisper format (dispatcher)
  - `parse_whisper_with_words()` - Whisper with word-level timestamps
  - `parse_whisper_without_words()` - Whisper segment-level only
  - `parse_whisper_cpp()` - Whisper.cpp format
  - `parse_pred_text()` - Custom pred_text format

### Code Quality Improvements
- **Removed Dead Code** - Eliminated ~80 lines of commented-out code
- **Better Error Messages** - Replaced generic errors like "what to do?" with descriptive messages
  - e.g., "Expected exactly 1 nBest result, got N"
  - e.g., "Could not find unique speaker label for segment X-Y"
- **Renamed Helper Methods** for clarity:
  - `ibmsp()` → `find_ibm_speaker()`
  - `gcts()` → `google_cloud_timestamp()`
  - `gctsv2()` → `google_cloud_v2_timestamp()`
- **Added Constants** - Extracted magic numbers to named constants:
  - `SPEECH_DURATION_THRESHOLD = 5 * 60` (was inline `60 * 5`)

### Documentation
- **Added Class-Level Documentation** - Comprehensive overview of Sample class with supported formats and examples
- **Added Method Documentation** - YARD-style docs for all public methods with:
  - Parameter types and descriptions
  - Return value descriptions
  - Exception documentation
- **Added Inline Comments** - Clarified complex parsing logic and helper methods

### File Size Reduction
- **Before:** 763 lines
- **After:** 772 lines
- Net change: +9 lines (documentation added outweighs code removed)
- Complexity: Significantly reduced through method extraction

### Test Updates
- Updated `test_init_from_google_cloud_v1_json` to verify the fix works correctly
- All 36 tests pass with 166 assertions (was 162)
- Updated test documentation to reflect fixed Google Cloud v1 support

### Impact Summary
- ✅ 2 critical bugs fixed (v1 parser, string literal warning)
- ✅ 80+ lines of dead code removed
- ✅ 13 new well-documented parser methods
- ✅ Complexity greatly reduced (204-line method → 13 focused methods)
- ✅ All tests passing
- ✅ Comprehensive documentation added

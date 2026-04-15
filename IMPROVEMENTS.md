# Suggested Improvements for lib/models.rb

## Critical Bugs

### 1. **Google Cloud v1 Parser Unreachable** (lib/models.rb:217-238)
**Problem:** The v1 parser can never execute because v2 parser (line 198) matches first.

**Current code:**
```ruby
elsif object['results'] # assume google cloud v2
  # ... v2 parsing
elsif object['results'] # assume google cloud v1  ← UNREACHABLE!
  # ... v1 parsing
```

**Fix:** Check for distinguishing features first:
```ruby
elsif object['results']
  # Distinguish v1 from v2 by checking timestamp format
  first_word = object['results'].last['alternatives'].first['words'].first
  if first_word['startTime'].is_a?(Hash)
    # v1 format - has {seconds, nanos} objects
    parse_google_cloud_v1(object)
  elsif first_word['startOffset'].is_a?(String)
    # v2 format - has "1.5s" strings
    parse_google_cloud_v2(object)
  else
    raise "unknown Google Cloud format"
  end
```

### 2. **String Literal Mutation Warning** (lib/models.rb:508)
**Problem:** Mutating string literal with `succ!`

**Current:**
```ruby
spk = '`' unless map[y[:file]]
map[y[:file]][y[:speaker]] ||= spk.succ!.dup
```

**Fix:**
```ruby
spk = '`'.dup unless map[y[:file]]  # or use +''
map[y[:file]][y[:speaker]] ||= spk.succ!.dup
```

## Architecture Issues

### 3. **Massive `add_object` Method** (lib/models.rb:158-362)
**Problem:** 204-line method with 8 levels of nesting handling all JSON formats.

**Recommendation:** Extract format-specific parsers:
```ruby
def add_object(object:)
  case
  when object['monologues']
    parse_rev(object)
  when object['audio_metrics']
    parse_ibm(object)
  when object['results']
    parse_google_cloud(object)
  when object['source']
    parse_azure(object)
  when object['segments']
    parse_whisper(object)
  when object['transcription']
    parse_whisper_cpp(object)
  when object['pred_text']
    parse_pred_text(object)
  else
    raise "unknown JSON format"
  end
end

private

def parse_rev(object)
  raise "the file name must be set" if @fn.nil?
  set_header %w[ file beg end text speaker ]
  object['monologues'].each do |m|
    speaker = m['speaker']
    m['elements'].each do |e|
      next unless e['type'] == 'text'
      @segments << {
        file: @fn,
        beg: e['ts'],
        end: e['end_ts'],
        text: e['value'],
        speaker: speaker
      }
    end
  end
end

def parse_ibm(object)
  # ... similar extraction
end
```

**Benefits:**
- Each parser is 10-30 lines instead of 200+
- Easier to test individually
- Easier to add new formats
- Better error messages per format

### 4. **Hardcoded File Paths** (lib/models.rb:317, 685)
**Problem:** Production code depends on specific local paths:
```ruby
last = `soxi -D /clinical/poetry/#{fn}`
d = `soxi -D /clinical/poetry/penn_sound_audio/data/#{k}.flac`
```

**Fix:** Make configurable or use relative paths:
```ruby
def parse_pred_text(object, audio_base_path: ENV['AUDIO_BASE_PATH'])
  fn = object['audio_filepath']
  raise "AUDIO_BASE_PATH not set" unless audio_base_path
  full_path = File.join(audio_base_path, fn)
  last = `soxi -D #{full_path}`.to_f
  # ...
end
```

## Code Quality Issues

### 5. **Dead/Commented Code**
Remove or uncomment:
- Lines 100-114: Large commented block
- Lines 326-358: 30+ lines of alternative whisper.cpp parsing
- Lines 457-459: Commented alternatives in `stm` method
- Method `sumx` (690-704): Appears unused, has `exit` statement

**Action:** Delete commented code or move to git history.

### 6. **Magic Numbers** (lib/models.rb:536)
```ruby
if t >= 60 * 5  # What does 5 minutes mean here?
```

**Fix:**
```ruby
SPEECH_DURATION_THRESHOLD = 5 * 60  # 5 minutes in seconds

if t >= SPEECH_DURATION_THRESHOLD
```

### 7. **Poor Error Messages**
**Examples:**
- Line 244: `raise "what to do?"`
- Line 368: `raise "what to do?"`

**Fix:**
```ruby
raise "Expected exactly 1 nBest result, got #{x['nBest'].count}"
raise "Could not find unique speaker label for segment #{b}-#{e}"
```

### 8. **Inconsistent Method Naming**
- `gcts` / `gctsv2` / `ibmsp` - unclear abbreviations
- `print_findx` vs `print_find` - what's the 'x'?

**Fix:**
```ruby
def google_cloud_timestamp(time_obj)        # was: gcts
def google_cloud_v2_timestamp(time_string)  # was: gctsv2
def find_ibm_speaker(labels, beg, end)      # was: ibmsp
```

### 9. **Missing Input Validation**
**Example:** `add_segment_from_tsv` doesn't validate numeric fields:
```ruby
def add_segment_from_tsv(line:)
  # ...
  @header_array.zip(a).each do |k, v|
    case k
    when 'beg', 'end'
      v = v.to_f  # No validation - returns 0.0 for invalid input
    end
    segment[k.to_sym] = v
  end
end
```

**Fix:**
```ruby
when 'beg', 'end'
  v = Float(v) rescue raise("Invalid timestamp '#{v}' in line: #{line}")
```

### 10. **No Documentation**
The 763-line class has only one comment: `# a uniform set of segments`

**Add:**
```ruby
# Represents a collection of speech transcript segments with uniform schema.
#
# Supports parsing multiple input formats:
# - TSV (tab-separated values)
# - CTM (NIST Conversation Time Marked)
# - JSON formats: Rev.ai, Whisper, Google Cloud, IBM Watson, Azure
#
# Example:
#   sample = Sample.new
#   sample.init_from(string: File.read('transcript.tsv'))
#   sample.print  # Output as TSV
#   puts sample.stm  # Convert to STM format
class Sample
  # @return [Array<String>] Column names for the current format
  attr_accessor :header_array

  # @return [Array<Hash>] Transcript segments with :file, :beg, :end, :text, etc.
  attr_accessor :segments
```

## Organization Suggestions

### 11. **Extract Format Parsers into Module**
```ruby
# lib/models.rb
require_relative 'models/parsers'

class Sample
  include Parsers
  # ... core methods only
end

# lib/models/parsers.rb
module Parsers
  def parse_rev(object)
    # ...
  end

  def parse_ibm(object)
    # ...
  end
end
```

### 12. **Extract Format Writers into Module**
```ruby
# lib/models/writers.rb
module Writers
  def to_stm
    # current stm method
  end

  def to_ctm
    # current ctm method
  end

  def to_rttm(directory)
    # current rttm method
  end
end
```

### 13. **Move Utility Methods**
Methods like `fix_parens`, `num` could be in a separate utility module:
```ruby
module TextNormalizer
  def fix_parens(text)
    # ...
  end

  def num(token)
    # ...
  end
end
```

## Testing Recommendations

### 14. **Add Validation Methods**
```ruby
def valid?
  return false if @segments.empty?
  return false unless @header_array
  @segments.all? { |s| segment_valid?(s) }
end

private

def segment_valid?(seg)
  return false unless seg[:file] && seg[:beg] && seg[:end] && seg[:text]
  return false if seg[:beg] < 0 || seg[:end] < 0
  return false if seg[:end] < seg[:beg]
  true
end
```

## Performance Considerations

### 15. **Inefficient String Operations** (lib/models.rb:679-684)
```ruby
slices[x[:file]] << (b...e).to_a  # Creates huge arrays for long segments!
# e.g., 1-second segment = 1000-element array
```

**Fix:** Use range objects or proper interval arithmetic:
```ruby
slices[x[:file]] << (b...e)  # Keep as range
# Then: slices[k].sum { |r| r.size }
```

### 16. **Repeated File Operations** (lib/models.rb:685)
```ruby
@segments.each do |x|
  # ... inside loop:
  d = `soxi -D /clinical/poetry/penn_sound_audio/data/#{k}.flac`
end
```

**Fix:** Cache duration lookups or move outside loop.

## Priority Recommendations

**High Priority:**
1. Fix Google Cloud v1 bug
2. Fix string literal warning
3. Extract `add_object` into separate parsers
4. Remove hardcoded paths
5. Improve error messages

**Medium Priority:**
6. Remove dead/commented code
7. Add input validation
8. Add method documentation
9. Extract constants for magic numbers

**Low Priority:**
10. Refactor into modules
11. Rename unclear methods
12. Add validation methods
13. Performance optimizations

## Estimated Impact

| Change | LOC Reduced | Complexity Reduced | Bugs Fixed |
|--------|-------------|-------------------|------------|
| Extract parsers | -150 | High | 1 (v1) |
| Remove dead code | -80 | Medium | 0 |
| Fix literals | -1 | Low | 1 (warning) |
| Add docs | +100 | N/A | 0 |
| **Total** | **~-130** | **High** | **2** |

Would you like me to implement any of these improvements?

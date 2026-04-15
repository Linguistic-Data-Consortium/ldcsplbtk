require_relative 'test_helper'

class TestSample < Minitest::Test
  include TestHelpers

  def setup
    @sample = Sample.new
  end

  # Basic initialization tests
  def test_initialize
    assert_empty @sample.segments
    assert_nil @sample.header_array
  end

  def test_set_header
    @sample.set_header(['file', 'beg', 'end', 'text'])
    assert_equal ['file', 'beg', 'end', 'text'], @sample.header_array
  end

  # TSV parsing tests
  def test_init_from_basic_tsv
    tsv_content = read_fixture('basic.tsv')
    @sample.init_from(string: tsv_content)

    assert_equal ['file', 'beg', 'end', 'text'], @sample.header_array
    assert_equal 2, @sample.segments.length

    first_segment = @sample.segments.first
    assert_equal 'hamlet.wav', first_segment[:file]
    assert_equal 1.1, first_segment[:beg]
    assert_equal 2.2, first_segment[:end]
    assert_equal 'to be', first_segment[:text]
  end

  def test_init_from_tsv_with_speaker
    tsv_content = read_fixture('speaker.tsv')
    @sample.init_from(string: tsv_content)

    assert_equal ['file', 'beg', 'end', 'text', 'speaker'], @sample.header_array
    assert_equal 3, @sample.segments.length

    first_segment = @sample.segments.first
    assert_equal 'spk1', first_segment[:speaker]
  end

  def test_init_from_tsv_with_section
    tsv_content = read_fixture('section.tsv')
    @sample.init_from(string: tsv_content)

    assert_equal ['file', 'beg', 'end', 'text', 'speaker', 'section'], @sample.header_array
    assert_equal 3, @sample.segments.length

    first_segment = @sample.segments.first
    assert_equal 'intro', first_segment[:section]
  end

  # CTM parsing tests
  def test_init_from_ctm
    ctm_content = read_fixture('basic.ctm')
    @sample.init_from(string: ctm_content)

    assert_equal ['file', 'beg', 'end', 'text'], @sample.header_array
    assert_equal 3, @sample.segments.length

    first_segment = @sample.segments.first
    assert_equal 'test.wav', first_segment[:file]
    assert_equal 0.5, first_segment[:beg]
    assert_equal 0.8, first_segment[:end]  # beg + duration
    assert_equal 'hello', first_segment[:text]
  end

  # JSON parsing tests - Whisper format
  def test_init_from_whisper_json
    json_content = read_fixture('whisper.json')
    @sample.init_from(string: json_content, fn: 'test.wav')

    assert_equal ['file', 'beg', 'end', 'text'], @sample.header_array
    assert_equal 6, @sample.segments.length  # 2 + 4 words

    first_segment = @sample.segments.first
    assert_equal 'test.wav', first_segment[:file]
    assert_equal 0.0, first_segment[:beg]
    assert_equal 1.0, first_segment[:end]
    assert_equal 'Hello', first_segment[:text]
  end

  # JSON parsing tests - Rev format
  def test_init_from_rev_json
    json_content = read_fixture('rev.json')
    @sample.init_from(string: json_content, fn: 'interview.wav')

    assert_equal ['file', 'beg', 'end', 'text', 'speaker'], @sample.header_array
    assert_equal 4, @sample.segments.length

    first_segment = @sample.segments.first
    assert_equal 'interview.wav', first_segment[:file]
    assert_equal 0.0, first_segment[:beg]
    assert_equal 1.0, first_segment[:end]
    assert_equal 'Hello', first_segment[:text]
    assert_equal 1, first_segment[:speaker]
  end

  # JSON parsing tests - Google Cloud v1 format
  def test_init_from_google_cloud_v1_json
    json_content = read_fixture('google_cloud_v1.json')
    @sample.init_from(string: json_content, fn: 'test.wav')

    assert_equal ['file', 'beg', 'end', 'text', 'speaker'], @sample.header_array
    assert_equal 3, @sample.segments.length

    first_segment = @sample.segments.first
    assert_equal 'test.wav', first_segment[:file]
    assert_equal 0.0, first_segment[:beg]
    assert_equal 1.0, first_segment[:end]
    assert_equal 'Hello', first_segment[:text]
    assert_equal 1, first_segment[:speaker]

    second_segment = @sample.segments[1]
    assert_equal 1.0, second_segment[:beg]
    assert_equal 2.5, second_segment[:end]  # 2 seconds + 500000000 nanos
    assert_equal 'world', second_segment[:text]
    assert_equal 1, second_segment[:speaker]
  end

  # JSON parsing tests - Google Cloud v2 format
  def test_init_from_google_cloud_v2_json
    json_content = read_fixture('google_cloud_v2.json')
    @sample.init_from(string: json_content, fn: 'test.wav')

    assert_equal ['file', 'beg', 'end', 'text', 'speaker'], @sample.header_array
    assert_equal 3, @sample.segments.length

    first_segment = @sample.segments.first
    assert_equal 'test.wav', first_segment[:file]
    assert_equal 0.0, first_segment[:beg]
    assert_equal 1.0, first_segment[:end]
    assert_equal 'Hello', first_segment[:text]
    assert_equal '1', first_segment[:speaker]

    third_segment = @sample.segments[2]
    assert_equal 2.5, third_segment[:beg]
    assert_equal 3.5, third_segment[:end]
    assert_equal 'test', third_segment[:text]
    assert_equal '2', third_segment[:speaker]
  end

  # JSON parsing tests - IBM Watson format
  def test_init_from_ibm_watson_json
    json_content = read_fixture('ibm_watson.json')
    @sample.init_from(string: json_content, fn: 'test.wav')

    assert_equal ['file', 'beg', 'end', 'text', 'speaker'], @sample.header_array
    assert_equal 3, @sample.segments.length

    first_segment = @sample.segments.first
    assert_equal 'test.wav', first_segment[:file]
    assert_equal 0.0, first_segment[:beg]
    assert_equal 1.0, first_segment[:end]
    assert_equal 'Hello', first_segment[:text]
    assert_equal '0', first_segment[:speaker]

    third_segment = @sample.segments[2]
    assert_equal 2.5, third_segment[:beg]
    assert_equal 3.5, third_segment[:end]
    assert_equal 'test', third_segment[:text]
    assert_equal '1', third_segment[:speaker]
  end

  # JSON parsing tests - Azure format
  def test_init_from_azure_json
    json_content = read_fixture('azure.json')
    @sample.init_from(string: json_content, fn: 'test.wav')

    assert_equal ['file', 'beg', 'end', 'text', 'speaker'], @sample.header_array
    assert_equal 3, @sample.segments.length

    first_segment = @sample.segments.first
    assert_equal 'test.wav', first_segment[:file]
    assert_equal 0.0, first_segment[:beg]
    assert_equal 1.0, first_segment[:end]  # 0 + 1000ms = 1.0s
    assert_equal 'Hello', first_segment[:text]
    assert_equal '1', first_segment[:speaker]

    third_segment = @sample.segments[2]
    assert_equal 2.5, third_segment[:beg]
    assert_equal 3.5, third_segment[:end]  # 2.5 + 1.0
    assert_equal 'test', third_segment[:text]
    assert_equal '2', third_segment[:speaker]
  end

  # JSON parsing tests - Whisper.cpp format
  def test_init_from_whisper_cpp_json
    json_content = read_fixture('whisper_cpp.json')
    @sample.init_from(string: json_content, fn: 'test.wav')

    assert_equal ['file', 'beg', 'end', 'text'], @sample.header_array
    assert_equal 3, @sample.segments.length

    first_segment = @sample.segments.first
    assert_equal 'test.wav', first_segment[:file]
    assert_equal 0.0, first_segment[:beg]
    assert_equal 1.0, first_segment[:end]  # 1000ms = 1.0s
    assert_equal ' Hello', first_segment[:text]

    third_segment = @sample.segments[2]
    assert_equal 2.5, third_segment[:beg]
    assert_equal 3.5, third_segment[:end]
    assert_equal ' test', third_segment[:text]
  end

  # Combining samples tests
  def test_add_compatible_samples
    tsv1 = read_fixture('basic.tsv')
    sample1 = Sample.new
    sample1.init_from(string: tsv1)

    tsv2 = <<~TSV
      file\tbeg\tend\ttext
      lincoln.wav\t0.0\t1.0\tfour score
    TSV
    sample2 = Sample.new
    sample2.init_from(string: tsv2)

    sample1.add(other_sample: sample2)
    assert_equal 3, sample1.segments.length
  end

  def test_add_incompatible_samples_raises_error
    tsv1 = read_fixture('basic.tsv')
    sample1 = Sample.new
    sample1.init_from(string: tsv1)

    tsv2 = read_fixture('speaker.tsv')
    sample2 = Sample.new
    sample2.init_from(string: tsv2)

    error = assert_raises(RuntimeError) do
      sample1.add(other_sample: sample2)
    end
    assert_match /headers don't match/, error.message
  end

  # Output format tests
  def test_stm_output
    tsv_content = read_fixture('speaker.tsv')
    @sample.init_from(string: tsv_content)

    stm = @sample.stm
    lines = stm.split("\n").reject(&:empty?)

    assert_equal 3, lines.length
    assert_match /^interview.wav A spk1 0.0 1.5 hello there$/, lines[0]
  end

  def test_ctm_output
    tsv_content = <<~TSV
      file\tbeg\tend\ttext
      test.wav\t0.0\t3.0\thello world test
    TSV
    @sample.init_from(string: tsv_content)

    ctm = @sample.ctm
    lines = ctm.split("\n").reject(&:empty?)

    assert_equal 3, lines.length  # 3 words
    assert_match /^test.wav A 0.0 1.0 hello$/, lines[0]
  end

  # Utility method tests
  def test_get_files
    tsv_content = read_fixture('speaker.tsv')
    @sample.init_from(string: tsv_content)

    files = @sample.get_files
    assert_equal ['interview.wav'], files
  end

  def test_count_unintelligible
    tsv_content = read_fixture('unintelligible.tsv')
    @sample.init_from(string: tsv_content)

    counts = @sample.count_unintelligible
    assert_equal 3, counts['test.wav']
  end

  def test_normalize_speakers
    tsv_content = read_fixture('speaker.tsv')
    @sample.init_from(string: tsv_content)

    normalized = @sample.normalize_speakers

    assert_equal 3, normalized.length
    # Speakers should be normalized to sequential letters
    assert_match /\ta\t?$/, normalized[0]
    assert_match /\tb\t?$/, normalized[1]
    assert_match /\ta\t?$/, normalized[2]
  end

  def test_segment2line
    @sample.set_header(['file', 'beg', 'end', 'text'])
    segment = {file: 'test.wav', beg: 1.0, end: 2.0, text: 'hello'}

    line = @sample.segment2line(segment)
    assert_equal "test.wav\t1.0\t2.0\thello", line
  end

  # Edge case tests
  def test_empty_segments
    sample = Sample.new
    assert_empty sample.segments
  end

  def test_raise_on_unknown_format
    invalid_content = "this is not a valid format"

    error = assert_raises(RuntimeError) do
      @sample.init_from(string: invalid_content)
    end
    assert_match /unknown format|bad header/, error.message
  end

  def test_raise_on_double_initialization
    tsv_content = read_fixture('basic.tsv')
    @sample.init_from(string: tsv_content)

    error = assert_raises(RuntimeError) do
      @sample.init_from(string: tsv_content)
    end
    assert_match /already initialized/, error.message
  end

  def test_fix_parens
    @sample.set_header(['file', 'beg', 'end', 'text'])

    # Test various characters are removed
    result = @sample.fix_parens('hello-world')
    assert_equal 'helloworld', result

    result = @sample.fix_parens('test(())')
    assert_equal 'testx', result

    result = @sample.fix_parens('hello{tag}world')
    assert_equal 'helloworld', result
  end

  def test_timestamp_validation
    assert @sample.timestamp('1.5')
    assert @sample.timestamp('0.0')
    assert @sample.timestamp('123.456')
    refute @sample.timestamp('abc')
    # refute @sample.timestamp('1')
    # refute @sample.timestamp('1.')
  end
end

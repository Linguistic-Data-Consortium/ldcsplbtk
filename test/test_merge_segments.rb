require_relative 'test_helper'

class TestMergeSegments < Minitest::Test
  include TestHelpers

  def setup
    @sample = Sample.new
  end

  # Basic merging tests
  def test_merge_segments_basic
    tsv_content = <<~TSV
      file\tbeg\tend\ttext
      test.wav\t0.0\t1.0\thello
      test.wav\t1.2\t2.0\tworld
      test.wav\t2.1\t3.0\ttest
    TSV
    @sample.init_from(string: tsv_content)

    # Gaps: 0.2, 0.1 - both should merge with threshold 0.5
    merged = @sample.merge_segments(threshold: 0.5)

    assert_equal 1, merged.segments.length
    seg = merged.segments.first
    assert_equal 0.0, seg[:beg]
    assert_equal 3.0, seg[:end]
    assert_equal 'hello world test', seg[:text]
  end

  def test_merge_segments_no_merging_large_gaps
    tsv_content = <<~TSV
      file\tbeg\tend\ttext
      test.wav\t0.0\t1.0\thello
      test.wav\t2.0\t3.0\tworld
      test.wav\t5.0\t6.0\ttest
    TSV
    @sample.init_from(string: tsv_content)

    # Gaps: 1.0, 2.0 - none should merge with threshold 0.5
    merged = @sample.merge_segments(threshold: 0.5)

    assert_equal 3, merged.segments.length
    assert_equal 'hello', merged.segments[0][:text]
    assert_equal 'world', merged.segments[1][:text]
    assert_equal 'test', merged.segments[2][:text]
  end

  def test_merge_segments_threshold_boundary
    tsv_content = <<~TSV
      file\tbeg\tend\ttext
      test.wav\t0.0\t1.0\ta
      test.wav\t1.5\t2.0\tb
      test.wav\t2.5\t3.0\tc
      test.wav\t4.0\t5.0\td
    TSV
    @sample.init_from(string: tsv_content)

    # Gaps: 0.5, 0.5, 1.0
    # With threshold 0.5: first two gaps are NOT < 0.5, so no merging
    merged = @sample.merge_segments(threshold: 0.5)
    assert_equal 4, merged.segments.length

    # With threshold 0.51: first two gaps < 0.51, should merge
    merged = @sample.merge_segments(threshold: 0.51)
    assert_equal 2, merged.segments.length
    assert_equal 'a b c', merged.segments[0][:text]
    assert_equal 'd', merged.segments[1][:text]

    # With threshold 1.0: last gap is NOT < 1.0
    merged = @sample.merge_segments(threshold: 1.0)
    assert_equal 2, merged.segments.length

    # With threshold 1.1: all gaps < 1.1
    merged = @sample.merge_segments(threshold: 1.1)
    assert_equal 1, merged.segments.length
    assert_equal 'a b c d', merged.segments[0][:text]
  end

  # Different files - should NOT merge across files
  def test_merge_segments_different_files
    tsv_content = <<~TSV
      file\tbeg\tend\ttext
      file1.wav\t0.0\t1.0\thello
      file1.wav\t1.1\t2.0\tworld
      file2.wav\t0.0\t1.0\tfoo
      file2.wav\t1.1\t2.0\tbar
    TSV
    @sample.init_from(string: tsv_content)

    merged = @sample.merge_segments(threshold: 0.5)

    assert_equal 2, merged.segments.length

    # Check that file1 segments were merged
    file1_seg = merged.segments.find { |s| s[:file] == 'file1.wav' }
    assert file1_seg
    assert_equal 'hello world', file1_seg[:text]

    # Check that file2 segments were merged
    file2_seg = merged.segments.find { |s| s[:file] == 'file2.wav' }
    assert file2_seg
    assert_equal 'foo bar', file2_seg[:text]
  end

  # Speaker handling - should NOT merge across different speakers
  def test_merge_segments_different_speakers
    tsv_content = <<~TSV
      file\tbeg\tend\ttext\tspeaker
      test.wav\t0.0\t1.0\thello\tspk1
      test.wav\t1.1\t2.0\tthere\tspk1
      test.wav\t2.1\t3.0\thi\tspk2
      test.wav\t3.2\t4.0\tback\tspk1
    TSV
    @sample.init_from(string: tsv_content)

    merged = @sample.merge_segments(threshold: 0.5)

    # Should have 3 segments: spk1+spk1, spk2, spk1
    assert_equal 3, merged.segments.length
    assert_equal 'hello there', merged.segments[0][:text]
    assert_equal 'spk1', merged.segments[0][:speaker]
    assert_equal 'hi', merged.segments[1][:text]
    assert_equal 'spk2', merged.segments[1][:speaker]
    assert_equal 'back', merged.segments[2][:text]
    assert_equal 'spk1', merged.segments[2][:speaker]
  end

  def test_merge_segments_same_speaker
    tsv_content = <<~TSV
      file\tbeg\tend\ttext\tspeaker
      test.wav\t0.0\t1.0\tone\tspk1
      test.wav\t1.1\t2.0\ttwo\tspk1
      test.wav\t2.1\t3.0\tthree\tspk1
    TSV
    @sample.init_from(string: tsv_content)

    merged = @sample.merge_segments(threshold: 0.5)

    # All same speaker with small gaps - should merge into one
    assert_equal 1, merged.segments.length
    assert_equal 'one two three', merged.segments[0][:text]
    assert_equal 'spk1', merged.segments[0][:speaker]
  end

  # Edge cases
  def test_merge_segments_single_segment
    tsv_content = <<~TSV
      file\tbeg\tend\ttext
      test.wav\t0.0\t1.0\thello
    TSV
    @sample.init_from(string: tsv_content)

    merged = @sample.merge_segments(threshold: 0.5)

    assert_equal 1, merged.segments.length
    assert_equal 'hello', merged.segments[0][:text]
  end

  def test_merge_segments_empty_sample
    @sample.set_header(['file', 'beg', 'end', 'text'])

    merged = @sample.merge_segments(threshold: 0.5)

    assert_equal 0, merged.segments.length
  end

  def test_merge_segments_zero_threshold
    tsv_content = <<~TSV
      file\tbeg\tend\ttext
      test.wav\t0.0\t1.0\ta
      test.wav\t1.0\t2.0\tb
      test.wav\t2.0\t3.0\tc
    TSV
    @sample.init_from(string: tsv_content)

    # Gap is exactly 0.0, should merge with threshold > 0
    merged = @sample.merge_segments(threshold: 0.1)
    assert_equal 1, merged.segments.length

    # Gap is 0.0, should NOT merge with threshold 0 (< not <=)
    merged = @sample.merge_segments(threshold: 0.0)
    assert_equal 3, merged.segments.length
  end

  def test_merge_segments_partial_merging
    tsv_content = <<~TSV
      file\tbeg\tend\ttext
      test.wav\t0.0\t1.0\ta
      test.wav\t1.2\t2.0\tb
      test.wav\t2.1\t3.0\tc
      test.wav\t5.0\t6.0\td
      test.wav\t6.3\t7.0\te
    TSV
    @sample.init_from(string: tsv_content)

    # Gaps: 0.2, 0.1, 2.0, 0.3
    # With threshold 0.5: first three merge (gaps 0.2, 0.1), last two merge (gap 0.3)
    merged = @sample.merge_segments(threshold: 0.5)

    assert_equal 2, merged.segments.length
    assert_equal 'a b c', merged.segments[0][:text]
    assert_equal 0.0, merged.segments[0][:beg]
    assert_equal 3.0, merged.segments[0][:end]

    assert_equal 'd e', merged.segments[1][:text]
    assert_equal 5.0, merged.segments[1][:beg]
    assert_equal 7.0, merged.segments[1][:end]
  end

  def test_merge_segments_preserves_header
    tsv_content = <<~TSV
      file\tbeg\tend\ttext\tspeaker\tsection
      test.wav\t0.0\t1.0\thello\tspk1\tintro
      test.wav\t1.1\t2.0\tworld\tspk1\tintro
    TSV
    @sample.init_from(string: tsv_content)

    merged = @sample.merge_segments(threshold: 0.5)

    assert_equal ['file', 'beg', 'end', 'text', 'speaker', 'section'], merged.header_array
    assert_equal 1, merged.segments.length
    assert_equal 'intro', merged.segments[0][:section]
  end

  # Complex scenario with multiple files and speakers
  def test_merge_segments_complex_scenario
    tsv_content = <<~TSV
      file\tbeg\tend\ttext\tspeaker
      file1.wav\t0.0\t1.0\ta\tspk1
      file1.wav\t1.1\t2.0\tb\tspk1
      file1.wav\t2.1\t3.0\tc\tspk2
      file2.wav\t0.0\t1.0\td\tspk1
      file2.wav\t5.0\t6.0\te\tspk1
      file1.wav\t3.2\t4.0\tf\tspk2
    TSV
    @sample.init_from(string: tsv_content)

    merged = @sample.merge_segments(threshold: 0.5)

    # file1: spk1 (a,b merged), spk2 (c,f merged)
    # file2: spk1 (d), spk1 (e) - gap too large
    assert_equal 4, merged.segments.length

    file1_segs = merged.segments.select { |s| s[:file] == 'file1.wav' }
    assert_equal 2, file1_segs.length

    file2_segs = merged.segments.select { |s| s[:file] == 'file2.wav' }
    assert_equal 2, file2_segs.length
  end
end

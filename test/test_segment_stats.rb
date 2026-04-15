require_relative 'test_helper'

class TestSegmentStats < Minitest::Test
  include TestHelpers

  def setup
    @sample = Sample.new
  end

  def test_average_segment_length
    tsv_content = <<~TSV
      file\tbeg\tend\ttext
      test.wav\t0.0\t1.0\thello
      test.wav\t2.0\t4.0\tworld
      test.wav\t5.0\t6.0\ttest
    TSV
    @sample.init_from(string: tsv_content)

    avg_lengths = @sample.average_segment_length

    assert_equal 1, avg_lengths.keys.length
    # Lengths: 1.0, 2.0, 1.0 -> average = 4.0/3 = 1.333...
    assert_in_delta 1.333, avg_lengths['test.wav'], 0.01
  end

  def test_average_segment_gap
    tsv_content = <<~TSV
      file\tbeg\tend\ttext
      test.wav\t0.0\t1.0\thello
      test.wav\t2.0\t4.0\tworld
      test.wav\t5.0\t6.0\ttest
    TSV
    @sample.init_from(string: tsv_content)

    avg_gaps = @sample.average_segment_gap

    assert_equal 1, avg_gaps.keys.length
    # Gaps: (2.0-1.0)=1.0, (5.0-4.0)=1.0 -> average = 2.0/2 = 1.0
    assert_in_delta 1.0, avg_gaps['test.wav'], 0.01
  end

  def test_average_segment_gap_no_gaps
    tsv_content = <<~TSV
      file\tbeg\tend\ttext
      test.wav\t0.0\t1.0\thello
    TSV
    @sample.init_from(string: tsv_content)

    avg_gaps = @sample.average_segment_gap

    # Only one segment, so no gaps
    assert_equal 0.0, avg_gaps['test.wav']
  end

  def test_segment_statistics
    tsv_content = <<~TSV
      file\tbeg\tend\ttext
      test.wav\t0.0\t1.0\thello
      test.wav\t2.0\t4.0\tworld
      test.wav\t5.0\t6.0\ttest
    TSV
    @sample.init_from(string: tsv_content)

    stats = @sample.segment_statistics

    assert_equal 1, stats.keys.length
    assert stats['test.wav']

    file_stats = stats['test.wav']
    assert_equal 3, file_stats[:count]
    assert_in_delta 1.333, file_stats[:avg_length], 0.01
    assert_in_delta 1.0, file_stats[:avg_gap], 0.01
    assert_in_delta 4.0, file_stats[:total_length], 0.01
  end

  def test_segment_statistics_multiple_files
    tsv_content = <<~TSV
      file\tbeg\tend\ttext
      file1.wav\t0.0\t2.0\thello
      file1.wav\t3.0\t5.0\tworld
      file2.wav\t0.0\t1.0\ttest
      file2.wav\t1.5\t2.5\tfoo
    TSV
    @sample.init_from(string: tsv_content)

    stats = @sample.segment_statistics

    assert_equal 2, stats.keys.length

    # file1: segments of length 2.0, 2.0; gap of 1.0
    assert_equal 2, stats['file1.wav'][:count]
    assert_in_delta 2.0, stats['file1.wav'][:avg_length], 0.01
    assert_in_delta 1.0, stats['file1.wav'][:avg_gap], 0.01
    assert_in_delta 4.0, stats['file1.wav'][:total_length], 0.01

    # file2: segments of length 1.0, 1.0; gap of 0.5
    assert_equal 2, stats['file2.wav'][:count]
    assert_in_delta 1.0, stats['file2.wav'][:avg_length], 0.01
    assert_in_delta 0.5, stats['file2.wav'][:avg_gap], 0.01
    assert_in_delta 2.0, stats['file2.wav'][:total_length], 0.01
  end

  def test_segment_statistics_with_overlapping_segments
    tsv_content = <<~TSV
      file\tbeg\tend\ttext
      test.wav\t0.0\t2.0\thello
      test.wav\t1.0\t3.0\tworld
    TSV
    @sample.init_from(string: tsv_content)

    stats = @sample.segment_statistics

    # Even with overlap, stats should be calculated
    assert_equal 2, stats['test.wav'][:count]
    assert_in_delta 2.0, stats['test.wav'][:avg_length], 0.01
    # Gap is negative (overlap), but we only count non-negative gaps
    # Since gap is -1.0 (next starts at 1.0, current ends at 2.0), no valid gaps
    assert_equal 0.0, stats['test.wav'][:avg_gap]
  end

  def test_segment_statistics_combined_mode
    tsv_content = <<~TSV
      file\tbeg\tend\ttext
      file1.wav\t0.0\t1.0\thello
      file1.wav\t1.5\t2.5\tworld
      file2.wav\t0.0\t2.0\tfoo
      file2.wav\t3.0\t5.0\tbar
    TSV
    @sample.init_from(string: tsv_content)

    stats = @sample.segment_statistics(combined: true)

    # Should have single 'combined' entry
    assert_equal 1, stats.keys.length
    assert stats['combined']

    combined_stats = stats['combined']
    assert_equal 4, combined_stats[:count]

    # Lengths: 1.0, 1.0, 2.0, 2.0 -> avg = 6.0/4 = 1.5
    assert_in_delta 1.5, combined_stats[:avg_length], 0.01

    # Gaps within file1: 1.5-1.0 = 0.5
    # Gaps within file2: 3.0-2.0 = 1.0
    # All gaps: [0.5, 1.0] -> avg = 1.5/2 = 0.75
    assert_in_delta 0.75, combined_stats[:avg_gap], 0.01

    # Total: 1.0 + 1.0 + 2.0 + 2.0 = 6.0
    assert_in_delta 6.0, combined_stats[:total_length], 0.01
  end

  def test_segment_statistics_combined_mode_single_file
    tsv_content = <<~TSV
      file\tbeg\tend\ttext
      test.wav\t0.0\t1.0\thello
      test.wav\t2.0\t4.0\tworld
      test.wav\t5.0\t6.0\ttest
    TSV
    @sample.init_from(string: tsv_content)

    stats = @sample.segment_statistics(combined: true)

    assert_equal 1, stats.keys.length
    assert stats['combined']

    combined_stats = stats['combined']
    assert_equal 3, combined_stats[:count]
    assert_in_delta 1.333, combined_stats[:avg_length], 0.01
    assert_in_delta 1.0, combined_stats[:avg_gap], 0.01
    assert_in_delta 4.0, combined_stats[:total_length], 0.01
  end

  def test_segment_statistics_combined_mode_empty
    @sample.set_header(['file', 'beg', 'end', 'text'])

    stats = @sample.segment_statistics(combined: true)

    assert_equal 0, stats.keys.length
  end
end

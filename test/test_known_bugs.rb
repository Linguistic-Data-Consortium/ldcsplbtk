require_relative 'test_helper'
require 'fileutils'

# Failing tests for the bugs identified in the code review (items 1a-1j).
#
# Each test asserts the CORRECT behavior, so it fails against the current
# implementation. Test names carry the review item letter; comments give the
# offending line in lib/models.rb and what actually happens today.
#
# Two of these encode a policy decision that has to be made rather than a
# clear-cut defect -- see test_e_* and test_h_*.
class TestKnownBugs < Minitest::Test
  include TestHelpers

  def setup
    @sample = Sample.new
    @bin_dir = File.join(__dir__, '..', 'bin')
  end

  # --- (a) Whisper segment-level parser corrupts the previous segment ------
  # lib/models.rb:393 -- `@segments[-1][:end] = segment['end']` indexes the
  # whole accumulated list, not the words of the current segment. When a
  # segment contributes no words, it rewrites a word belonging to the
  # PREVIOUS segment.
  #
  # Actual today: "world" ends at 3.0 instead of 2.0.

  def test_a_whisper_empty_segment_does_not_corrupt_previous_segment
    json = <<~JSON
      {"segments":[
        {"start":0.0,"end":2.0,"text":"hello world"},
        {"start":2.0,"end":3.0,"text":"   "},
        {"start":3.0,"end":4.0,"text":"bye"}
      ]}
    JSON
    @sample.init_from(string: json, fn: 'a.wav')

    hello, world, bye = @sample.segments

    assert_equal 3, @sample.segments.length,
      'the empty-text segment contributes no words, so 3 words total'

    assert_equal 0.0, hello[:beg]
    assert_equal 1.0, hello[:end]

    assert_equal 1.0, world[:beg]
    assert_equal 2.0, world[:end],
      "the empty segment must not extend the previous segment's last word"

    assert_equal 3.0, bye[:beg]
    assert_equal 4.0, bye[:end]
  end

  # lib/models.rb:380 -- `(segment['end'] - beg_time) / words.length` with
  # words.length == 0 yields Infinity for floats. Nothing is emitted today so
  # this is latent, but it must not produce non-finite timestamps.
  def test_a_whisper_empty_segment_produces_no_infinite_timestamps
    json = <<~JSON
      {"segments":[
        {"start":0.0,"end":2.0,"text":""},
        {"start":2.0,"end":4.0,"text":"hello"}
      ]}
    JSON
    @sample.init_from(string: json, fn: 'a.wav')

    @sample.segments.each do |seg|
      assert_predicate seg[:beg].to_f, :finite?, "non-finite beg in #{seg.inspect}"
      assert_predicate seg[:end].to_f, :finite?, "non-finite end in #{seg.inspect}"
    end
  end

  # --- (b) merge_segments truncates nested segments ------------------------
  # lib/models.rb:963 -- `current_merged[:end] = seg[:end]` assigns rather
  # than extends, so a segment contained inside a longer one moves the end
  # time backwards and silently discards audio.
  #
  # Actual today: the merged segment is 0.0-2.0, losing 8 seconds.

  def test_b_merge_segments_does_not_shorten_on_nested_segment
    tsv = <<~TSV
      file\tbeg\tend\ttext
      a.wav\t0.0\t10.0\tlong
      a.wav\t1.0\t2.0\tshort
      a.wav\t20.0\t21.0\tlater
    TSV
    @sample.init_from(string: tsv)

    merged = @sample.merge_segments(threshold: 0.5)

    assert_equal 2, merged.segments.length
    first = merged.segments.first

    assert_equal 0.0, first[:beg]
    assert_equal 10.0, first[:end],
      'merging a nested segment must keep the later of the two end times'
    assert_equal 'long short', first[:text]

    assert_equal 20.0, merged.segments.last[:beg]
    assert_equal 21.0, merged.segments.last[:end]
  end

  # A merged span must never be shorter than any of its inputs, whatever the
  # arrangement. This is the general invariant behind the case above.
  def test_b_merged_span_covers_every_input_segment
    tsv = <<~TSV
      file\tbeg\tend\ttext
      a.wav\t0.0\t5.0\tone
      a.wav\t0.5\t1.0\ttwo
      a.wav\t1.0\t3.0\tthree
    TSV
    @sample.init_from(string: tsv)

    merged = @sample.merge_segments(threshold: 1.0)

    assert_equal 1, merged.segments.length
    assert_equal 5.0, merged.segments.first[:end],
      'the merged span must cover the maximum end time of its inputs'
  end

  # --- (c) CTM column check is vacuous ------------------------------------
  # lib/models.rb:137-141 -- the 4-element slice is built BEFORE the length
  # check, so `a.length != @header_array.length` is always 4 != 4. A
  # truncated line yields text: nil and end == beg, which then blows up
  # downstream in ctm/text_only with a NoMethodError on nil.
  #
  # Actual today: parses silently into {beg: 0.5, end: 0.5, text: nil}.

  def test_c_ctm_short_line_is_rejected
    ctm = "a.wav 1 0.5 0.3 hello\nb.wav 1 0.5\n"

    error = assert_raises(RuntimeError) do
      @sample.init_from(string: ctm)
    end
    assert_match(/bad line/, error.message)
  end

  # Whatever the rejection policy, a parsed CTM segment must never carry a
  # nil text field.
  def test_c_ctm_never_produces_nil_text
    ctm = "a.wav 1 0.5 0.3 hello\nb.wav 1 0.5\n"

    begin
      @sample.init_from(string: ctm)
    rescue RuntimeError
      # rejecting the input is an acceptable outcome; nil text is not
      return
    end

    @sample.segments.each do |seg|
      refute_nil seg[:text], "nil text in #{seg.inspect}"
    end
  end

  # --- (d) count_overlap compares segments by value ------------------------
  # lib/models.rb:802 -- `next if x == y` is Hash value equality, so two
  # distinct segments that happen to have identical fields are treated as the
  # same object and skipped.
  #
  # Actual today: reports 0.0 overlap for two identical 2-second segments.

  def test_d_count_overlap_counts_identical_duplicate_segments
    tsv = <<~TSV
      file\tbeg\tend\ttext
      a.wav\t0.0\t2.0\thi
      a.wav\t0.0\t2.0\thi
    TSV
    @sample.init_from(string: tsv)

    assert_in_delta 2.0, @sample.count_overlap['a.wav'], 0.001,
      'two identical segments overlap for their full duration'
  end

  # Sanity check that the non-duplicate path still works, so a fix for the
  # above cannot regress it.
  def test_d_count_overlap_partial_overlap_still_correct
    tsv = <<~TSV
      file\tbeg\tend\ttext
      a.wav\t0.0\t2.0\thi
      a.wav\t1.5\t3.0\tthere
    TSV
    @sample.init_from(string: tsv)

    assert_in_delta 0.5, @sample.count_overlap['a.wav'], 0.001
  end

  # --- (e) missing key in after_time_with_map crashes ----------------------
  # lib/models.rb:460 -- `x[:end] > after_time_with_map[x[:file]]` raises
  # ArgumentError (comparison of Float with nil) as soon as the transcript
  # covers a file the durations map does not.
  #
  # POLICY DECISION: this test asserts that a file with no known duration is
  # omitted from the output, on the grounds that check_for_final_hallucination
  # reports segments PAST a known duration, and an unknown duration cannot
  # justify calling anything a hallucination. If you would rather pass such
  # segments through, flip the refute_match/assert_match below -- but either
  # way it must not raise.

  def test_e_after_time_with_map_tolerates_unknown_file
    tsv = <<~TSV
      file\tbeg\tend\ttext
      a.wav\t0.0\t1.0\tknown
      b.wav\t0.0\t9.0\tunknown
    TSV
    @sample.init_from(string: tsv)

    out, _err = capture_io do
      @sample.print(after_time_with_map: { 'a' => 0.5 })
    end

    assert_match(/^a\t/, out, 'a.wav ends past its 0.5s duration, so it is reported')
    refute_match(/^b\t/, out, 'b.wav has no known duration, so nothing can be reported')
  end

  # The same failure reached through the script the user actually runs.
  def test_e_check_for_final_hallucination_script_tolerates_unknown_file
    transcript = '/tmp/test_hallucination_transcript.tsv'
    durations  = '/tmp/test_hallucination_durations.tsv'
    File.write(transcript, "file\tbeg\tend\ttext\na.wav\t0.0\t1.0\tknown\nb.wav\t0.0\t9.0\tunknown\n")
    File.write(durations, "a\t0.5\n")

    output = `ruby #{@bin_dir}/check_for_final_hallucination.rb #{transcript} #{durations} 2>&1`

    assert $?.success?, "script failed:\n#{output}"
  ensure
    [transcript, durations].each { |f| File.unlink(f) if f && File.exist?(f) }
  end

  # --- (f) two documented input formats never parse ------------------------
  # lib/models.rb:90-104 -- both branches set a 4-column header for 3-column
  # data, so every data row raises "bad line, 3 columns". The `file` column
  # has to be synthesized from the fn: argument.
  #
  # Neither format has existing test coverage, which is why this went
  # unnoticed.

  def test_f_start_end_text_header_uses_filename_argument
    tsv = "start\tend\ttext\n0.0\t1.0\thello\n1.0\t2.0\tworld\n"

    @sample.init_from(string: tsv, fn: 'interview.wav')

    assert_equal %w[file beg end text], @sample.header_array
    assert_equal 2, @sample.segments.length

    first = @sample.segments.first
    assert_equal 'interview.wav', first[:file],
      'the file column is taken from the fn: argument'
    assert_equal 0.0, first[:beg]
    assert_equal 1.0, first[:end]
    assert_equal 'hello', first[:text]
  end

  def test_f_sad_speech_non_speech_format_parses
    tsv = "0.0\t1.0\tspeech\n1.0\t2.0\tnon-speech\n2.0\t3.0\tspeech\n"

    @sample.init_from(string: tsv, fn: 'interview.wav')

    assert_equal %w[file beg end text], @sample.header_array
    assert_equal 3, @sample.segments.length

    first = @sample.segments.first
    assert_equal 'interview.wav', first[:file]
    assert_equal 0.0, first[:beg]
    assert_equal 1.0, first[:end]
    assert_equal 'speech', first[:text]
    assert_equal 'non-speech', @sample.segments[1][:text]
  end

  # --- (g) init_from_arg never passes fn:, so JSON input fails everywhere --
  # lib/models.rb:755-760 -- init_from_arg calls init_from(string:) without
  # fn:, so every vendor JSON parser hits `raise "Filename must be set"`.
  # This affects the 10 bin/ scripts that go through init_from_arg; only
  # combine.rb, merge_segments.rb and segment_stats.rb build the Sample
  # themselves.
  #
  # Actual today: RuntimeError "Filename must be set".

  def test_g_init_from_arg_sets_filename_from_argv
    original_argv = ARGV.dup
    ARGV.replace([fixture_path('whisper.json')])

    @sample.init_from_arg

    refute_empty @sample.segments
    # Basename, not the absolute fixture path: split/rttm interpolate this
    # column into output filenames and stm/ctm write it as the waveform id,
    # so a directory prefix breaks them and makes output cwd-dependent.
    assert_equal 'whisper.json', @sample.segments.first[:file]
  ensure
    ARGV.replace(original_argv)
  end

  def test_g_stm_script_accepts_json_input
    output = `ruby #{@bin_dir}/stm.rb #{fixture_path('whisper.json')} 2>&1`

    assert $?.success?, "stm.rb rejected JSON input:\n#{output}"
    refute_empty output.strip
    refute_match %r{/}, output,
      'the waveform id must not carry a directory prefix'
  end

  def test_g_ctm_script_accepts_json_input
    output = `ruby #{@bin_dir}/ctm.rb #{fixture_path('whisper.json')} 2>&1`

    assert $?.success?, "ctm.rb rejected JSON input:\n#{output}"
    refute_empty output.strip
    refute_match %r{/}, output,
      'the waveform id must not carry a directory prefix'
  end

  # split and rttm derive output filenames from the file column, so an
  # absolute path there makes them fail with Errno::ENOENT on a path like
  # "outdir//abs/path/to/rev.json.tsv".
  def test_g_split_script_accepts_json_input
    dir = '/tmp/test_known_bugs_split'
    FileUtils.mkdir_p(dir)

    output = `ruby #{@bin_dir}/split.rb #{fixture_path('rev.json')} #{dir} 2>&1`

    assert $?.success?, "split.rb failed on JSON input:\n#{output}"
    assert_equal ['rev.json.tsv'], Dir.children(dir).sort
  ensure
    FileUtils.rm_rf(dir)
  end

  def test_g_rttm_script_accepts_json_input
    dir = '/tmp/test_known_bugs_rttm'
    FileUtils.mkdir_p(dir)

    output = `ruby #{@bin_dir}/rttm.rb #{fixture_path('rev.json')} #{dir} 2>&1`

    assert $?.success?, "rttm.rb failed on JSON input:\n#{output}"
    assert_equal ['rev.json.rttm'], Dir.children(dir).sort
  ensure
    FileUtils.rm_rf(dir)
  end

  # --- (h) stm emits a malformed line when there is no speaker column ------
  # lib/models.rb:517 -- x[:speaker] is nil for 4-column input, producing
  # "hamlet.wav A  1.1 2.2 to be" with an empty field where the speaker
  # belongs. That is not valid NIST STM.
  #
  # POLICY DECISION: this test asserts a non-empty placeholder is emitted.
  # Raising a clear error instead would be equally defensible -- in that case
  # replace the body with assert_raises. What must not happen is silently
  # writing a malformed file.

  def test_h_stm_without_speaker_column_is_well_formed
    @sample.init_from(string: read_fixture('basic.tsv'))

    @sample.stm.each_line do |line|
      next if line.strip.empty?
      # NB: split(/ /) not split(' ') -- the latter is awk-mode and collapses
      # runs of whitespace, which would hide the empty field entirely.
      fields = line.chomp.split(/ /, 6)
      assert_equal 6, fields.length, "malformed STM line: #{line.inspect}"
      fields[0..4].each_with_index do |field, i|
        refute_empty field, "empty STM field #{i} in: #{line.inspect}"
      end
    end
  end

  # --- (i) print destructively mutates @segments ---------------------------
  # lib/models.rb:451-453 -- print_prep rewrites x[:file] in place, so the
  # first print strips extensions permanently and a later call's
  # strip_extensions: false has nothing left to preserve.
  #
  # Actual today: the second print still shows "hamlet".

  def test_i_print_does_not_mutate_segments
    @sample.init_from(string: read_fixture('basic.tsv'))

    capture_io { @sample.print }

    assert_equal 'hamlet.wav', @sample.segments.first[:file],
      'print must not rewrite the segments it renders'
  end

  def test_i_second_print_honors_strip_extensions_false
    @sample.init_from(string: read_fixture('basic.tsv'))

    capture_io { @sample.print }
    out, _err = capture_io { @sample.print(strip_extensions: false) }

    assert_match(/^hamlet\.wav\t/, out,
      'strip_extensions: false must keep the extension regardless of earlier calls')
  end

  # --- (j) printone ignores its own arguments ------------------------------
  # lib/models.rb:471-473 -- the method signature accepts norm:, after_time:
  # and after_time_with_map:, then passes hardcoded false/nil/nil to
  # print_prep, so every argument is discarded.
  #
  # Actual today: text comes back un-normalized.
  #
  # NOTE: printone is currently unreachable from bin/ (review section 2). If
  # you decide to delete it rather than fix it, delete this test with it.

  def test_j_printone_honors_norm_argument
    tsv = <<~TSV
      file\tbeg\tend\ttext
      a.wav\t0.0\t1.0\tTo Be,
      a.wav\t1.0\t2.0\tOr Not To Be.
    TSV
    @sample.init_from(string: tsv)

    out, _err = capture_io { @sample.printone(norm: true) }

    assert_match(/to be or not to be/, out,
      'printone must apply the norm: argument it accepts')
  end

  def test_j_printone_honors_after_time_argument
    tsv = <<~TSV
      file\tbeg\tend\ttext
      a.wav\t0.0\t1.0\tearly
      a.wav\t5.0\t6.0\tlate
    TSV
    @sample.init_from(string: tsv)

    out, _err = capture_io { @sample.printone(after_time: 4.0) }

    refute_match(/early/, out, 'printone must apply the after_time: filter it accepts')
    assert_match(/late/, out)
  end
end

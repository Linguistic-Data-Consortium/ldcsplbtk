require_relative 'test_helper'

class TestBinScripts < Minitest::Test
  include TestHelpers

  def setup
    @bin_dir = File.join(__dir__, '..', 'bin')
  end

  def test_combine_script
    result = `ruby #{@bin_dir}/combine.rb #{fixture_path('basic.tsv')}`

    assert $?.success?
    assert_match /file\tbeg\tend\ttext/, result
    # Note: print_prep strips file extensions, so hamlet.wav becomes hamlet
    assert_match /hamlet\t1.1\t2.2\tto be/, result
    assert_match /hamlet\t3.3\t4.4\tor not to be/, result
  end

  def test_combine_multiple_files
    result = `ruby #{@bin_dir}/combine.rb #{fixture_path('basic.tsv')} #{fixture_path('basic.tsv')}`

    assert $?.success?
    lines = result.split("\n")
    # Header + 2 segments from first file + 2 segments from second file
    assert_equal 5, lines.length
  end

  def test_stm_script
    result = `ruby #{@bin_dir}/stm.rb #{fixture_path('speaker.tsv')}`

    assert $?.success?
    assert_match /interview.wav A spk1 0.0 1.5 hello there/, result
    assert_match /interview.wav A spk2 1.5 3.0 how are you/, result
  end

  def test_ctm_script
    result = `ruby #{@bin_dir}/ctm.rb #{fixture_path('basic.tsv')}`

    assert $?.success?
    assert_match /hamlet.wav A/, result
  end

  def test_print_files_script
    result = `ruby #{@bin_dir}/print_files.rb #{fixture_path('basic.tsv')}`

    assert $?.success?
    assert_match /hamlet.wav/, result
  end

  def test_count_unintelligible_script
    result = `ruby #{@bin_dir}/count_unintelligible.rb #{fixture_path('unintelligible.tsv')}`

    assert $?.success?
    assert_match /file\tunintelligible/, result
    assert_match /test.wav\t3/, result
  end

  def test_count_overlap_script
    # Create a fixture with overlapping segments
    overlap_tsv = <<~TSV
      file\tbeg\tend\ttext\tspeaker
      test.wav\t0.0\t2.0\thello\tspk1
      test.wav\t1.0\t3.0\tworld\tspk2
    TSV

    temp_file = '/tmp/test_overlap.tsv'
    File.write(temp_file, overlap_tsv)

    result = `ruby #{@bin_dir}/count_overlap.rb #{temp_file}`

    assert $?.success?
    assert_match /file\toverlap/, result
    assert_match /test.wav\t1.0/, result

    File.delete(temp_file) if File.exist?(temp_file)
  end

  def test_normalize_speakers_script
    result = `ruby #{@bin_dir}/normalize_speakers.rb #{fixture_path('speaker.tsv')}`

    assert $?.success?
    # Speakers should be normalized to sequential letters
    assert_match /\ta\n/, result
    assert_match /\tb\n/, result
  end

  def test_split_script
    temp_dir = '/tmp/test_split_output'
    Dir.mkdir(temp_dir) unless Dir.exist?(temp_dir)

    `ruby #{@bin_dir}/split.rb #{fixture_path('basic.tsv')} #{temp_dir}`

    assert $?.success?
    assert File.exist?("#{temp_dir}/hamlet.wav.tsv")

    # Clean up
    Dir.glob("#{temp_dir}/*.tsv").each { |f| File.delete(f) }
    Dir.rmdir(temp_dir)
  end

  def test_text_only_script
    temp_dir = '/tmp/test_text_only_output'
    Dir.mkdir(temp_dir) unless Dir.exist?(temp_dir)

    `ruby #{@bin_dir}/text_only.rb #{fixture_path('basic.tsv')} #{temp_dir}`

    assert $?.success?
    # Note: output filename includes original extension
    assert File.exist?("#{temp_dir}/hamlet.wav.txt")

    content = File.read("#{temp_dir}/hamlet.wav.txt")
    assert_match /to be or not to be/, content

    # Clean up
    Dir.glob("#{temp_dir}/*.txt").each { |f| File.delete(f) }
    Dir.rmdir(temp_dir)
  end
end

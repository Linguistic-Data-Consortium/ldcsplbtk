require_relative 'test_helper'

class TestCombineOptions < Minitest::Test
  include TestHelpers

  def setup
    @bin_dir = File.join(__dir__, '..', 'bin')
    @basic_tsv = fixture_path('basic.tsv')
  end

  def test_combine_strips_extensions_by_default
    result = `#{@bin_dir}/combine.rb #{@basic_tsv}`

    assert $?.success?
    assert_match /^hamlet\t1.1\t2.2\tto be/, result
    refute_match /hamlet\.wav/, result
  end

  def test_combine_with_strip_ext_flag
    result = `#{@bin_dir}/combine.rb --strip-ext #{@basic_tsv}`

    assert $?.success?
    assert_match /^hamlet\t1.1\t2.2\tto be/, result
    refute_match /hamlet\.wav/, result
  end

  def test_combine_with_s_flag
    result = `#{@bin_dir}/combine.rb -s #{@basic_tsv}`

    assert $?.success?
    assert_match /^hamlet\t1.1\t2.2\tto be/, result
    refute_match /hamlet\.wav/, result
  end

  def test_combine_with_keep_ext_flag
    result = `#{@bin_dir}/combine.rb --keep-ext #{@basic_tsv}`

    assert $?.success?
    assert_match /^hamlet\.wav\t1.1\t2.2\tto be/, result
    refute_match /^hamlet\t/, result
  end

  def test_combine_with_k_flag
    result = `#{@bin_dir}/combine.rb -k #{@basic_tsv}`

    assert $?.success?
    assert_match /^hamlet\.wav\t1.1\t2.2\tto be/, result
    refute_match /^hamlet\t/, result
  end

  def test_combine_multiple_files_with_keep_ext
    result = `#{@bin_dir}/combine.rb --keep-ext #{@basic_tsv} #{@basic_tsv}`

    assert $?.success?
    lines = result.split("\n")
    # Header + 2 segments from first file + 2 segments from second file
    assert_equal 5, lines.length
    assert_match /hamlet\.wav/, lines[1]
    assert_match /hamlet\.wav/, lines[2]
  end
end

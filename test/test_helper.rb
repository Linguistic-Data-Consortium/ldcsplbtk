require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/models'

module TestHelpers
  def fixture_path(filename)
    File.join(__dir__, 'fixtures', filename)
  end

  def read_fixture(filename)
    File.read(fixture_path(filename))
  end
end

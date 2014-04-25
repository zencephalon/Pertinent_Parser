require 'minitest/autorun'
require 'pertinent_parser'

class PertinentParserTest < MiniTest::Test
  def test_basic_parse
    assert_equal(PertinentParser.html("A <i>sentence with</i> some markup."), "A sentence with some markup.")
    assert_equal(PertinentParser.html("A <i>sentence with</i> <b>some more</b> markup."), "A sentence with some more markup.")
  end
end

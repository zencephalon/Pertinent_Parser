require 'minitest/autorun'
require 'pertinent_parser'

class PertinentParserTest < MiniTest::Test
  def test_basic_parse
    assert_equal("A sentence with some markup.", PertinentParser.html("A <i>sentence with</i> some markup."))
    assert_equal("A sentence with some more markup.", PertinentParser.html("A <i>sentence with</i> <b>some more</b> markup."))
  end

  def test_basic_wrap_in
    h = PertinentParser.html("A sentence with no markup.")
    h.wrap_in("<b>", "with no")
    assert_equal("A sentence <b>with no</b> markup.", h.apply)
  end

  def test_wrap_in_across_boundary
    h = PertinentParser.html("A <i>sentence with</i> some markup.")
    h.wrap_in("<b>", "with some")
    assert_equal("A <i>sentence <b>with</b></i><b> some</b> markup.", h.apply)
  end
end

require 'test_helper'

class ApplicationHelperTest < ActionView::TestCase

  test "full title helper" do
    assert_equal full_title,         "Cantilever Beam Sim App"
    assert_equal full_title("Help"), "Help | Cantilever Beam Sim App"
  end
end

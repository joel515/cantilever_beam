require 'test_helper'

class StaticPagesControllerTest < ActionController::TestCase

  test "should get home" do
    get :home
    assert_response :success
    assert_select "title", full_title()
  end

  test "should get help" do
    get :help
    assert_response :success
    assert_select "title", full_title("Help")
  end

  test "should get contact" do
    get :contact
    assert_response :success
    assert_select "title", full_title("Contact")
  end

  test "should get about" do
    get :about
    assert_response :success
    assert_select "title", full_title("About")
  end

end

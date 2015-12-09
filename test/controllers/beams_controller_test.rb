require 'test_helper'

class BeamsControllerTest < ActionController::TestCase

  test "should get new" do
    get :new
    assert_response :success
  end

  # test "should redirect index when no beams exist" do
  #   get :index
  #   assert_redirected_to root_url
  # end
end

require 'test_helper'

class JobsControllerTest < ActionController::TestCase
  test "should get submit" do
    get :submit
    assert_response :success
  end

  test "should get kill" do
    get :kill
    assert_response :success
  end

end

require 'test_helper'

class BeamsControllerTest < ActionController::TestCase

  test "should get index" do
    get :index
    assert_response :success
    assert_select "title", full_title("Beams")
  end

  test "should get new" do
    get :new
    assert_response :success
    assert_select "title", full_title("New")
  end

  test "should get show" do
    get :show
    assert_response :success
    assert_select "title", full_title("Beam")
  end

  test "should get edit" do
    get :edit
    assert_response :success
    assert_select "title", full_title("Edit")
  end

  test "should get results" do
    get :results
    assert_response :success
    assert_select "title", full_title("Results")
  end

end

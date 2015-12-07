require 'test_helper'

class BeamsControllerTest < ActionController::TestCase

  def setup
    @base_title = "Cantilever Beam Sim App"
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_select "title", "Beams | #{@base_title}"
  end

  test "should get new" do
    get :new
    assert_response :success
    assert_select "title", "New | #{@base_title}"
  end

  test "should get show" do
    get :show
    assert_response :success
    assert_select "title", "Beam | #{@base_title}"
  end

  test "should get edit" do
    get :edit
    assert_response :success
    assert_select "title", "Edit | #{@base_title}"
  end

  test "should get results" do
    get :results
    assert_response :success
    assert_select "title", "Results | #{@base_title}"
  end

end

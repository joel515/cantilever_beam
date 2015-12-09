require 'test_helper'

class BeamsCreateTest < ActionDispatch::IntegrationTest

  test "invalid beam creation information" do
    get create_path
    assert_no_difference 'Beam.count' do
      post beams_path, beam: { name: "",
                               length: "length",
                               width: nil,
                               height: -1.0,
                               meshsize: "size",
                               material: nil,
                               modulus: -10000,
                               poisson: 1.0,
                               density: "density",
                               load: nil }
    end
    assert_template 'beams/new'
    assert_select 'div#error_explanation'
    assert_select 'div.alert.alert-danger'
  end

  test "valid beam creation information" do
    get create_path
    assert_difference 'Beam.count', 1 do
      post_via_redirect beams_path, beam: { name: "Example Beam",
                                    length: 1,
                                    width: 0.1,
                                    height: 0.05,
                                    meshsize: 0.01,
                                    material: "Steel",
                                    modulus: 2.0e11,
                                    poisson: 0.29,
                                    density: 7600,
                                    load: 2000 }
    end
    assert_template 'beams/show'
    assert_not flash.empty?
  end
end

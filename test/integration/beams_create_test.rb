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
  end
end

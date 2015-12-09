require 'test_helper'

class BeamIndexTest < ActionDispatch::IntegrationTest

  def setup
    @beam = beams(:steel)
  end

  test "index including pagination" do
    get beams_path
    assert_template 'beams/index'
    assert_select 'div.pagination'
    Beam.paginate(page: 1).each do |beam|
      assert_select 'a[href=?]', beam_path(beam), text: beam.name
    end
  end
end

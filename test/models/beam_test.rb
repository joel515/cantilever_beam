require 'test_helper'

class BeamTest < ActiveSupport::TestCase

  def setup
    @beam = Beam.new(name: "Example Beam", length: 1.0, width: 0.1,
                     height: 0.05, meshsize: 0.01, modulus: 2.0e11,
                     poisson: 0.29, density: 7600, material: "Steel",
                     load: 2000)
  end

  test "should be valid" do
    assert @beam.valid?
  end

  test "name should be present" do
    @beam.name = "     "
    assert_not @beam.valid?
  end

  test "length should be number greater than 0" do
    @beam.length = nil
    assert_not @beam.valid?
    @beam.length = "length"
    assert_not @beam.valid?
    @beam.length = -1.0
    assert_not @beam.valid?
  end

  test "width should be number greater than 0" do
    @beam.width = nil
    assert_not @beam.valid?
    @beam.width = "width"
    assert_not @beam.valid?
    @beam.width = -1.0
    assert_not @beam.valid?
  end

  test "height should be number greater than 0" do
    @beam.height = nil
    assert_not @beam.valid?
    @beam.height = "height"
    assert_not @beam.valid?
    @beam.height = -1.0
    assert_not @beam.valid?
  end

  test "mesh size should be number greater than 0" do
    @beam.meshsize = nil
    assert_not @beam.valid?
    @beam.meshsize = "meshsize"
    assert_not @beam.valid?
    @beam.meshsize = -1.0
    assert_not @beam.valid?
  end

  test "modulus should be number greater than 0" do
    @beam.modulus = nil
    assert_not @beam.valid?
    @beam.modulus = "modulus"
    assert_not @beam.valid?
    @beam.modulus = -1.0
    assert_not @beam.valid?
  end

  test "Poisson's ratio should be a number between -1.0 and 0.5" do
    @beam.poisson = nil
    assert_not @beam.valid?
    @beam.poisson = "poisson"
    assert_not @beam.valid?
    @beam.poisson = -1.5
    assert_not @beam.valid?
    @beam.poisson = 1.0
    assert_not @beam.valid?
  end

  test "density should be number greater than 0" do
    @beam.density = nil
    assert_not @beam.valid?
    @beam.density = "density"
    assert_not @beam.valid?
    @beam.density = -1.0
    assert_not @beam.valid?
  end

  test "material should be present" do
    @beam.material = "     "
    assert_not @beam.valid?
  end

  test "load should be number greater than or equal to 0" do
    @beam.load = nil
    assert_not @beam.valid?
    @beam.load = "load"
    assert_not @beam.valid?
    @beam.load = -1.0
    assert_not @beam.valid?
    @beam.load = 0
    assert @beam.valid?
  end
end

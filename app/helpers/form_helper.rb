module FormHelper
  def setup_beam(beam)
    beam.material = Material.count > 0 ? Material.find(1) : Material.create!
    beam
  end
end

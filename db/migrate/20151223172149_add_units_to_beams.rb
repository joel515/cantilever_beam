class AddUnitsToBeams < ActiveRecord::Migration
  def change
    add_column :beams, :length_unit, :string, default: "m"
    add_column :beams, :width_unit, :string, default: "m"
    add_column :beams, :height_unit, :string, default: "m"
    add_column :beams, :meshsize_unit, :string, default: "m"
    add_column :beams, :modulus_unit, :string, default: "gpa"
    add_column :beams, :density_unit, :string, default: "kgm3"
    add_column :beams, :load_unit, :string, default: "n"
  end
end

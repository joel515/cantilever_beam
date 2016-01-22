class RemoveMaterialFromBeams < ActiveRecord::Migration
  def change
    remove_column :beams, :material, :string
    remove_column :beams, :modulus, :float
    remove_column :beams, :poisson, :float
    remove_column :beams, :density, :float
    remove_column :beams, :modulus_unit, :string
    remove_column :beams, :density_unit, :string
  end
end

class ChangeMaterialDefaultValues < ActiveRecord::Migration
  def change
    change_column :materials, :name,    :string, default: "Structural Steel"
    change_column :materials, :modulus, :float,  default: 200.0
    change_column :materials, :poisson, :float,  default: 0.3
    change_column :materials, :density, :float,  default: 7850.0
  end
end

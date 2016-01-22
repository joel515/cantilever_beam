class CreateMaterials < ActiveRecord::Migration
  def change
    create_table :materials do |t|
      t.string :name
      t.float :modulus
      t.float :poisson
      t.float :density
      t.string :modulus_unit, default: "gpa"
      t.string :density_unit, default: "kgm3"

      t.timestamps null: false
    end
  end
end

class CreateBeams < ActiveRecord::Migration
  def change
    create_table :beams do |t|
      t.string :name
      t.float :length
      t.float :width
      t.float :height
      t.float :meshsize
      t.float :modulus
      t.float :poisson
      t.float :density
      t.string :material

      t.timestamps null: false
    end
  end
end

class AddMaterialRefToBeams < ActiveRecord::Migration
  def change
    add_reference :beams, :material, index: true, foreign_key: true
  end
end

class AddIndexToBeamsName < ActiveRecord::Migration
  def change
    add_index :beams, :name, unique: true
  end
end

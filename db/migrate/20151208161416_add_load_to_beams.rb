class AddLoadToBeams < ActiveRecord::Migration
  def change
    add_column :beams, :load, :float
  end
end

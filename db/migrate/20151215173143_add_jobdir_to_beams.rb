class AddJobdirToBeams < ActiveRecord::Migration
  def change
    add_column :beams, :jobdir, :string
  end
end

class AddStatusToBeams < ActiveRecord::Migration
  def change
    add_column :beams, :status, :boolean, default: false
  end
end

class RemoveJobFromBeams < ActiveRecord::Migration
  def change
    remove_column :beams, :status, :string
    remove_column :beams, :jobdir, :string
    remove_column :beams, :jobid, :string
    remove_column :beams, :cores, :integer
  end
end

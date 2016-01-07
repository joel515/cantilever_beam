class AddJobidToBeams < ActiveRecord::Migration
  def change
    add_column :beams, :jobid, :string
  end
end

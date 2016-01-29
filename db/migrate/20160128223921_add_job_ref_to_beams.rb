class AddJobRefToBeams < ActiveRecord::Migration
  def change
    add_reference :beams, :job, index: true, foreign_key: true
  end
end

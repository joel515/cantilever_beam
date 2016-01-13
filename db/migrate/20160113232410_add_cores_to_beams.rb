class AddCoresToBeams < ActiveRecord::Migration
  def change
    add_column :beams, :cores, :integer, default: 1
  end
end

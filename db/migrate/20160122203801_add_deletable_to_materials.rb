class AddDeletableToMaterials < ActiveRecord::Migration
  def change
    add_column :materials, :deletable, :boolean, default: true
  end
end

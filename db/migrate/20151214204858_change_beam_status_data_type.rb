class ChangeBeamStatusDataType < ActiveRecord::Migration
  def change
    change_column :beams, :status, :string, default: "Unsubmitted"
  end
end

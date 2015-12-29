class AddResultUnitSystemToBeams < ActiveRecord::Migration
  def change
    add_column :beams, :result_unit_system, :string, default: "metric_mpa"
  end
end

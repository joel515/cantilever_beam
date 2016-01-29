class CreateJobs < ActiveRecord::Migration
  def change
    create_table :jobs do |t|
      t.string :pid
      t.string :jobdir
      t.string :status, default: "Unsubmitted"
      t.string :config, default: "elmer"
      t.integer :cores, default: 1
      t.integer :machines, default: 1

      t.timestamps null: false
    end
  end
end

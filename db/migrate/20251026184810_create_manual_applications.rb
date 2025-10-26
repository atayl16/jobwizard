class CreateManualApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :manual_applications do |t|
      t.string :company
      t.string :position
      t.date :applied_at
      t.string :status
      t.text :notes
      t.string :job_url

      t.timestamps
    end
  end
end

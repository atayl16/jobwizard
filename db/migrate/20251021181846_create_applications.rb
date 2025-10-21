class CreateApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :applications do |t|
      t.references :job_posting, null: true, foreign_key: true
      t.string :company, null: false
      t.string :role, null: false
      t.text :job_description, null: false
      t.json :flags, default: {}
      t.string :output_path
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :applications, :company
    add_index :applications, :status
    add_index :applications, :created_at
  end
end

class CreateJobPostings < ActiveRecord::Migration[8.0]
  def change
    create_table :job_postings do |t|
      t.string :company, null: false
      t.string :title, null: false
      t.text :description, null: false
      t.string :location
      t.boolean :remote, default: false
      t.datetime :posted_at
      t.string :url, null: false
      t.string :source
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :job_postings, :url, unique: true
    add_index :job_postings, :company
    add_index :job_postings, :remote
    add_index :job_postings, :posted_at
  end
end

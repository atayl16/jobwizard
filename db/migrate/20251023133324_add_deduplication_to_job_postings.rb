class AddDeduplicationToJobPostings < ActiveRecord::Migration[8.0]
  def change
    add_column :job_postings, :external_id, :string
    add_column :job_postings, :last_seen_at, :datetime
    add_column :job_postings, :ignored_at, :datetime
    
    # Add unique index for deduplication (where external_id is not null)
    add_index :job_postings, [:source, :external_id], unique: true, where: "external_id IS NOT NULL"
    add_index :job_postings, :last_seen_at
  end
end

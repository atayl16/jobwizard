class AddStatusToJobPostings < ActiveRecord::Migration[8.0]
  def change
    add_column :job_postings, :status, :string, default: 'suggested', null: false
    add_column :job_postings, :applied_at, :datetime
    add_column :job_postings, :exported_at, :datetime
    
    add_index :job_postings, :status
  end
end



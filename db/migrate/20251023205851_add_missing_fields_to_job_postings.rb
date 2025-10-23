class AddMissingFieldsToJobPostings < ActiveRecord::Migration[8.0]
  def change
    add_column :job_postings, :rejected_at, :datetime
    add_column :job_postings, :rejected_reason, :string
    add_column :job_postings, :notes, :text
    add_column :job_postings, :snooze_until, :datetime
  end
end

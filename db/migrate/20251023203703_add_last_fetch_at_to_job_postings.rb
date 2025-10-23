class AddLastFetchAtToJobPostings < ActiveRecord::Migration[8.0]
  def change
    add_column :job_postings, :last_fetch_at, :datetime
  end
end

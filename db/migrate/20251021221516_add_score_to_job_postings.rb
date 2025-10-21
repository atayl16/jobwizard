class AddScoreToJobPostings < ActiveRecord::Migration[8.0]
  def change
    add_column :job_postings, :score, :float, default: 0.0, null: false
  end
end

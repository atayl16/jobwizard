class AddMissingIndexes < ActiveRecord::Migration[8.0]
  def change
    # Add index for output_path lookups on applications
    add_index :applications, :output_path unless index_exists?(:applications, :output_path)
    
    # Add index for created_at on job_postings (used in sorting)
    add_index :job_postings, :created_at unless index_exists?(:job_postings, :created_at)
  end
end
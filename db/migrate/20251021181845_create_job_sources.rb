class CreateJobSources < ActiveRecord::Migration[8.0]
  def change
    create_table :job_sources do |t|
      t.string :name, null: false
      t.string :provider, null: false
      t.string :slug, null: false
      t.boolean :active, default: true
      t.datetime :last_fetched_at

      t.timestamps
    end

    add_index :job_sources, [:provider, :slug], unique: true
    add_index :job_sources, :active
  end
end

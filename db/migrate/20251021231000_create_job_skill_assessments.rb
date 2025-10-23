class CreateJobSkillAssessments < ActiveRecord::Migration[8.0]
  def change
    create_table :job_skill_assessments do |t|
      t.integer :job_posting_id, null: false
      t.string :skill_name, null: false
      t.boolean :have, null: false, default: false
      t.integer :proficiency, null: true
      
      t.timestamps
    end
    
    add_index :job_skill_assessments, [:job_posting_id, :skill_name], unique: true
    add_index :job_skill_assessments, :skill_name
    add_foreign_key :job_skill_assessments, :job_postings
  end
end

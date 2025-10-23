class CreateBlockedCompanies < ActiveRecord::Migration[8.0]
  def change
    create_table :blocked_companies do |t|
      t.string :name, null: false
      t.boolean :pattern, default: false, null: false
      t.string :reason, null: false
      
      t.timestamps
    end
    
    add_index :blocked_companies, :name
    add_index :blocked_companies, :pattern
  end
end



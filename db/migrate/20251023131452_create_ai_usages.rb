class CreateAiUsages < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_usages do |t|
      t.string :model, null: false
      t.string :feature, null: false
      t.integer :prompt_tokens, default: 0, null: false
      t.integer :completion_tokens, default: 0, null: false
      t.integer :cached_input_tokens, default: 0, null: false
      t.integer :cost_cents, default: 0, null: false
      t.json :meta
      
      t.timestamps
    end
    
    add_index :ai_usages, :created_at
    add_index :ai_usages, :feature
  end
end

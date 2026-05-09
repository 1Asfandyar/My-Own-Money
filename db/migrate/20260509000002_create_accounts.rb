class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts do |t|
      t.references :user,     null: false, foreign_key: true
      t.references :currency, null: false, foreign_key: true
      t.string  :name,            null: false
      t.integer :initial_balance_cents, null: false, default: 0
      t.integer :current_balance_cents, null: false, default: 0
      t.boolean :is_archived,     null: false, default: false
      t.timestamps
    end
  end
end

class CreateDebts < ActiveRecord::Migration[8.0]
  def change
    create_table :debts do |t|
      t.references :from_user, null: false, foreign_key: { to_table: :users }
      t.references :to_user,   null: false, foreign_key: { to_table: :users }
      t.integer :amount_cents, null: false
      t.timestamps
    end

    add_index :debts, [:from_user_id, :to_user_id], unique: true
  end
end

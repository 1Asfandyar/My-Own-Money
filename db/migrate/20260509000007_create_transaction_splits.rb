class CreateTransactionSplits < ActiveRecord::Migration[8.0]
  def change
    create_table :transaction_splits do |t|
      t.references :transaction, null: false, foreign_key: true
      t.references :user,        null: false, foreign_key: true
      t.integer :split_method,     null: false
      t.decimal :allocation_value,  precision: 15, scale: 4
      t.integer :owed_amount_cents, null: false
      t.timestamps
    end
  end
end

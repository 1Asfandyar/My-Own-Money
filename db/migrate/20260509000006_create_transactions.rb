class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.references :user,     null: false, foreign_key: true
      t.references :account,  null: false, foreign_key: true
      t.references :category,             foreign_key: true
      t.references :currency, null: false, foreign_key: true
      t.references :group,                foreign_key: true
      t.integer  :transaction_type, null: false
      t.integer  :visibility_type,  null: false
      t.integer  :amount_cents,      null: false
      t.string   :title,            null: false
      t.text     :note
      t.datetime :transaction_date, null: false
      t.bigint   :transfer_account_id
      t.timestamps
    end

    add_foreign_key :transactions, :accounts, column: :transfer_account_id
    add_index :transactions, :transaction_date
    add_index :transactions, :transaction_type
  end
end

class AddSettlesUserIdToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_reference :transactions, :settles_user, null: true, foreign_key: { to_table: :users }
  end
end

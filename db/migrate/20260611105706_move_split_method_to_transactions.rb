class MoveSplitMethodToTransactions < ActiveRecord::Migration[8.1]
  def up
    add_column :transactions, :split_method, :integer

    # Backfill from the first split of each shared transaction
    execute <<~SQL
      UPDATE transactions
      SET split_method = (
        SELECT ts.split_method
        FROM transaction_splits ts
        WHERE ts.transaction_id = transactions.id
        LIMIT 1
      )
      WHERE visibility_type = 1
    SQL

    remove_column :transaction_splits, :split_method
  end

  def down
    add_column :transaction_splits, :split_method, :integer, null: false, default: 0

    # Restore split_method on each split from its parent transaction
    execute <<~SQL
      UPDATE transaction_splits
      SET split_method = transactions.split_method
      FROM transactions
      WHERE transaction_splits.transaction_id = transactions.id
        AND transactions.split_method IS NOT NULL
    SQL

    remove_column :transactions, :split_method
  end
end

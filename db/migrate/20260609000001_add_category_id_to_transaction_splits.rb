class AddCategoryIdToTransactionSplits < ActiveRecord::Migration[8.1]
  def change
    add_reference :transaction_splits, :category, null: true, foreign_key: true
  end
end

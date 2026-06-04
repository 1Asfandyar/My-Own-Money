class AddDefaultAccountToUser < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :default_account, foreign_key: { to_table: :accounts }
  end
end

class CreateFriendships < ActiveRecord::Migration[8.0]
  def change
    create_table :friendships do |t|
      t.references :user_a,        null: false, foreign_key: { to_table: :users }
      t.references :user_b,        null: false, foreign_key: { to_table: :users }
      t.references :requested_by,  null: false, foreign_key: { to_table: :users }
      t.integer    :status,        null: false, default: 0
      t.timestamps
    end

    add_check_constraint :friendships, "user_a_id < user_b_id"
    add_index :friendships, [:user_a_id, :user_b_id], unique: true
  end
end

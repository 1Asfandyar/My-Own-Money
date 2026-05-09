class CreateGroupsUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :groups_users do |t|
      t.references :group, null: false, foreign_key: true
      t.references :user,  null: false, foreign_key: true
      t.timestamps
    end

    add_index :groups_users, [:group_id, :user_id], unique: true
  end
end

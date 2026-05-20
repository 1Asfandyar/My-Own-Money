class RemoveKindFromGroups < ActiveRecord::Migration[8.0]
  def up
    remove_index :groups, name: "index_groups_on_created_by_id_and_friends_kind"
    remove_column :groups, :kind
  end

  def down
    add_column :groups, :kind, :integer, null: false, default: 0
    add_index :groups,
              [ :created_by_id, :kind ],
              unique: true,
              where: "kind = 1",
              name: "index_groups_on_created_by_id_and_friends_kind"
  end
end

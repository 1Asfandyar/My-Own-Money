class AddKindToGroups < ActiveRecord::Migration[8.0]
  FRIENDS_GROUP_DESCRIPTION = "Default group for all friends.".freeze

  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  class MigrationGroup < ActiveRecord::Base
    self.table_name = "groups"
  end

  class MigrationGroupsUser < ActiveRecord::Base
    self.table_name = "groups_users"
  end

  def up
    add_column :groups, :kind, :integer, null: false, default: 0
    add_index :groups,
              [ :created_by_id, :kind ],
              unique: true,
              where: "kind = 1",
              name: "index_groups_on_created_by_id_and_friends_kind"

    MigrationGroup.reset_column_information
    create_friends_groups_for_existing_users
  end

  def down
    remove_index :groups, name: "index_groups_on_created_by_id_and_friends_kind"
    remove_column :groups, :kind
  end

  private

  def create_friends_groups_for_existing_users
    MigrationUser.find_each do |user|
      group = MigrationGroup.find_or_create_by!(created_by_id: user.id, kind: 1) do |new_group|
        new_group.name = friends_group_name(user)
        new_group.description = FRIENDS_GROUP_DESCRIPTION
      end

      MigrationGroupsUser.find_or_create_by!(group_id: group.id, user_id: user.id)
    end
  end

  def friends_group_name(user)
    owner_name = user.full_name.presence || user.email.presence || "My"
    "#{owner_name}'s Friends"
  end
end

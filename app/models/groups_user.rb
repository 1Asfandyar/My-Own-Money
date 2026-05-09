# == Schema Information
#
# Table name: groups_users
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  group_id   :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_groups_users_on_group_id              (group_id)
#  index_groups_users_on_group_id_and_user_id  (group_id,user_id) UNIQUE
#  index_groups_users_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (group_id => groups.id)
#  fk_rails_...  (user_id => users.id)
#
class GroupsUser < ApplicationRecord
  validates :group_id, uniqueness: { scope: :user_id }

  belongs_to :group
  belongs_to :user
end

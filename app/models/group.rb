# == Schema Information
#
# Table name: groups
#
#  id            :bigint           not null, primary key
#  description   :text
#  name          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :bigint           not null
#
# Indexes
#
#  index_groups_on_created_by_id  (created_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#
class Group < ApplicationRecord
  validates :name, presence: true

  belongs_to :created_by, class_name: "User"
  has_many :groups_users
  has_many :users, through: :groups_users
  has_many :transactions
end

# == Schema Information
#
# Table name: friendships
#
#  id              :bigint           not null, primary key
#  status          :integer          default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  requested_by_id :bigint           not null
#  user_a_id       :bigint           not null
#  user_b_id       :bigint           not null
#
# Indexes
#
#  index_friendships_on_requested_by_id          (requested_by_id)
#  index_friendships_on_user_a_id                (user_a_id)
#  index_friendships_on_user_a_id_and_user_b_id  (user_a_id,user_b_id) UNIQUE
#  index_friendships_on_user_b_id                (user_b_id)
#
# Foreign Keys
#
#  fk_rails_...  (requested_by_id => users.id)
#  fk_rails_...  (user_a_id => users.id)
#  fk_rails_...  (user_b_id => users.id)
#
class Friendship < ApplicationRecord
  enum :status, { pending: 0, accepted: 1, blocked: 2 }

  belongs_to :user_a,       class_name: "User"
  belongs_to :user_b,       class_name: "User"
  belongs_to :requested_by, class_name: "User"

  validates :status, presence: true
  validate  :users_must_differ
  validate  :user_a_must_have_smaller_id

  scope :accepted, -> { where(status: :accepted) }
  scope :pending,  -> { where(status: :pending) }

  def other_user(current_user)
    current_user.id == user_a_id ? user_b : user_a
  end

  def involves?(user)
    user_a_id == user.id || user_b_id == user.id
  end

  private

  def users_must_differ
    errors.add(:user_b_id, "must be different from user_a") if user_a_id == user_b_id
  end

  def user_a_must_have_smaller_id
    return if user_a_id.blank? || user_b_id.blank?

    errors.add(:user_a_id, "must be the smaller ID") if user_a_id > user_b_id
  end
end

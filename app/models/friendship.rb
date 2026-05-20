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

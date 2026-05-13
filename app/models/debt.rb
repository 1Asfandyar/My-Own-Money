# == Schema Information
#
# Table name: debts
#
#  id           :bigint           not null, primary key
#  amount_cents :integer          not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  from_user_id :bigint           not null
#  to_user_id   :bigint           not null
#
# Indexes
#
#  index_debts_on_from_user_id                 (from_user_id)
#  index_debts_on_from_user_id_and_to_user_id  (from_user_id,to_user_id) UNIQUE
#  index_debts_on_to_user_id                   (to_user_id)
#
# Foreign Keys
#
#  fk_rails_...  (from_user_id => users.id)
#  fk_rails_...  (to_user_id => users.id)
#
class Debt < ApplicationRecord
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate  :users_must_differ

  belongs_to :from_user, class_name: "User"
  belongs_to :to_user,   class_name: "User"

  private

  def users_must_differ
    errors.add(:to_user_id, "must be different") if from_user_id == to_user_id
  end
end

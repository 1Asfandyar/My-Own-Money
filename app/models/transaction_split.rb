# == Schema Information
#
# Table name: transaction_splits
#
#  id               :bigint           not null, primary key
#  allocation_value  :decimal(15, 4)
#  owed_amount_cents :integer          not null
#  split_method     :integer          not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  transaction_id   :bigint           not null
#  user_id          :bigint           not null
#
# Indexes
#
#  index_transaction_splits_on_transaction_id  (transaction_id)
#  index_transaction_splits_on_user_id         (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (transaction_id => transactions.id)
#  fk_rails_...  (user_id => users.id)
#
class TransactionSplit < ApplicationRecord
  enum :split_method, { equal: 0, percentage: 1, shares: 2, exact: 3 }

  validates :owed_amount_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :split_method, presence: true

  validate :allocation_value_required

  belongs_to :financial_transaction, class_name: "Transaction", foreign_key: :transaction_id
  belongs_to :user

  private

  def allocation_value_required
    return unless percentage? || shares?

    errors.add(:allocation_value, "is required") if allocation_value.nil?
  end
end

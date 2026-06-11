# == Schema Information
#
# Table name: transaction_splits
#
#  id                :bigint           not null, primary key
#  allocation_value  :decimal(15, 4)
#  owed_amount_cents :integer          not null
#  split_method      :integer          not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  category_id       :bigint
#  transaction_id    :bigint           not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_transaction_splits_on_category_id     (category_id)
#  index_transaction_splits_on_transaction_id  (transaction_id)
#  index_transaction_splits_on_user_id         (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#  fk_rails_...  (transaction_id => transactions.id)
#  fk_rails_...  (user_id => users.id)
#
class TransactionSplit < ApplicationRecord
  validates :owed_amount_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :allocation_value_required

  belongs_to :financial_transaction, class_name: "Transaction", foreign_key: :transaction_id
  belongs_to :user
  belongs_to :category, optional: true

  private

  def allocation_value_required
    return unless financial_transaction&.split_percentage? || financial_transaction&.split_shares?

    errors.add(:allocation_value, "is required") if allocation_value.nil?
  end
end

# == Schema Information
#
# Table name: transactions
#
#  id                  :bigint           not null, primary key
#  amount_cents        :integer          not null
#  note                :text
#  title               :string           not null
#  transaction_date    :datetime         not null
#  transaction_type    :integer          not null
#  visibility_type     :integer          not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  category_id         :bigint
#  currency_id         :bigint           not null
#  group_id            :bigint
#  transfer_account_id :bigint
#  user_id             :bigint           not null
#
# Indexes
#
#  index_transactions_on_account_id        (account_id)
#  index_transactions_on_category_id       (category_id)
#  index_transactions_on_currency_id       (currency_id)
#  index_transactions_on_group_id          (group_id)
#  index_transactions_on_transaction_date  (transaction_date)
#  index_transactions_on_transaction_type  (transaction_type)
#  index_transactions_on_user_id           (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (category_id => categories.id)
#  fk_rails_...  (currency_id => currencies.id)
#  fk_rails_...  (group_id => groups.id)
#  fk_rails_...  (transfer_account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#
class Transaction < ApplicationRecord
  enum :transaction_type, { expense: 0, income: 1, transfer: 2, settlement: 3 }
  enum :visibility_type,  { personal: 0, shared: 1 }

  validates :amount_cents,     presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :title,            presence: true
  validates :transaction_type, presence: true
  validates :visibility_type,  presence: true

  validate :group_required_for_shared
  validate :transfer_account_required
  validate :transfer_accounts_must_differ

  belongs_to :user
  belongs_to :account
  belongs_to :category,         optional: true
  belongs_to :currency
  belongs_to :group,            optional: true
  belongs_to :transfer_account, class_name: "Account", optional: true
  has_many   :transaction_splits, dependent: :destroy

  private

  def group_required_for_shared
    errors.add(:group_id, "is required") if shared? && group_id.blank?
  end

  def transfer_account_required
    errors.add(:transfer_account_id, "is required") if transfer? && transfer_account_id.blank?
  end

  def transfer_accounts_must_differ
    errors.add(:transfer_account_id, "must be different") if transfer_account_id == account_id
  end
end

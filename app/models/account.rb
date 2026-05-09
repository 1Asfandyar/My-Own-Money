# == Schema Information
#
# Table name: accounts
#
#  id              :bigint           not null, primary key
#  current_balance_cents :integer          default(0), not null
#  initial_balance_cents :integer          default(0), not null
#  is_archived     :boolean          default(FALSE), not null
#  name            :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  currency_id     :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_accounts_on_currency_id  (currency_id)
#  index_accounts_on_user_id      (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (currency_id => currencies.id)
#  fk_rails_...  (user_id => users.id)
#
class Account < ApplicationRecord
  validates :name,            presence: true
  validates :initial_balance_cents, numericality: { only_integer: true }
  validates :current_balance_cents, numericality: { only_integer: true }

  belongs_to :user
  belongs_to :currency
  has_many :transactions
end

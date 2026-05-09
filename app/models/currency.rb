# == Schema Information
#
# Table name: currencies
#
#  id         :bigint           not null, primary key
#  code       :string           not null
#  name       :string           not null
#  symbol     :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_currencies_on_code  (code) UNIQUE
#
class Currency < ApplicationRecord
  validates :code,   presence: true, uniqueness: true
  validates :name,   presence: true
  validates :symbol, presence: true

  has_many :accounts
  has_many :transactions
end

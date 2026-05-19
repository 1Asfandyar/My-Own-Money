# == Schema Information
#
# Table name: categories
#
#  id            :bigint           not null, primary key
#  balance_cents :integer          default(0), not null
#  category_type :integer          not null
#  color         :string
#  icon          :string
#  name          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_categories_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Category < ApplicationRecord
  enum :category_type, { expense: 0, income: 1 }

  COLOR_FORMAT = /\A#[0-9A-Fa-f]{6}\z/.freeze

  validates :name,          presence: true
  validates :category_type, presence: true
  validates :color,         format: { with: COLOR_FORMAT }, allow_blank: true

  belongs_to :user
  has_many :transactions
end

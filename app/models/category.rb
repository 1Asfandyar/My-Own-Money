# == Schema Information
#
# Table name: categories
#
#  id            :bigint           not null, primary key
#  category_type :integer          not null
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

  validates :name,          presence: true
  validates :category_type, presence: true

  belongs_to :user
  has_many :transactions
end

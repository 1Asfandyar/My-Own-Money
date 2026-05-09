# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  full_name              :string
#  mobile_number          :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  role                   :integer          default("user"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_mobile_number         (mobile_number) UNIQUE WHERE (mobile_number IS NOT NULL)
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_role                  (role)
#
class User < ApplicationRecord
  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         :jwt_authenticatable,
         jwt_revocation_strategy: JwtBlacklist

  enum :role, { user: 0, admin: 1 }

  validates :email, presence: true, uniqueness: true
  validates :full_name, presence: true
  validates :mobile_number, presence: true, uniqueness: true

  has_many :accounts
  has_many :transactions
  has_many :transaction_splits
  has_many :groups_users
  has_many :groups, through: :groups_users
  has_many :debts_from, class_name: "Debt", foreign_key: :from_user_id
  has_many :debts_to,   class_name: "Debt", foreign_key: :to_user_id

  def admin?
    role == "admin"
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at email full_name id mobile_number role updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end

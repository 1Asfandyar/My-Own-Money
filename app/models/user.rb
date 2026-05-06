class User < ApplicationRecord
  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         :jwt_authenticatable,
         jwt_revocation_strategy: JwtBlacklist

  enum role: { user: 0, admin: 1 }

  validates :email, presence: true, uniqueness: true
  validates :full_name, presence: true
  validates :mobile_number, presence: true, uniqueness: true

  def admin?
    role == 'admin'
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at email full_name id mobile_number role updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end

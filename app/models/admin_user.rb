class AdminUser < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :rememberable,
         :validatable

  validates :email, presence: true, uniqueness: true
  validate :only_one_admin_user, on: :create

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at email id updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  private

  def only_one_admin_user
    errors.add(:base, "Only one admin user is allowed") if AdminUser.exists?
  end
end

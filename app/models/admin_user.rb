# == Schema Information
#
# Table name: admin_users
#
#  id                     :bigint           not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_admin_users_on_email                 (email) UNIQUE
#  index_admin_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_admin_users_singleton                ((true)) UNIQUE
#
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

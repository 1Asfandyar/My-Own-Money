# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  full_name              :string
#  mobile_number          :string
#  onboarding_completed   :boolean          default(FALSE), not null
#  provider               :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  role                   :integer          default("user"), not null
#  uid                    :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  default_account_id     :bigint
#
# Indexes
#
#  index_users_on_default_account_id    (default_account_id)
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_mobile_number         (mobile_number) UNIQUE WHERE (mobile_number IS NOT NULL)
#  index_users_on_provider_and_uid      (provider,uid) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_role                  (role)
#
# Foreign Keys
#
#  fk_rails_...  (default_account_id => accounts.id)
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
  validates :mobile_number, presence: true, unless: -> { provider.present? }
  validates :mobile_number, uniqueness: true, allow_nil: true

  belongs_to :currency, optional: true
  has_many :accounts
  belongs_to :default_account, class_name: "Account", foreign_key: :default_account_id, optional: true
  has_many :categories
  has_many :transactions
  has_many :transaction_splits
  has_many :groups_users
  has_many :groups, through: :groups_users
  has_many :created_groups, class_name: "Group", foreign_key: :created_by_id, inverse_of: :created_by
  has_many :debts_from, class_name: "Debt", foreign_key: :from_user_id
  has_many :debts_to,   class_name: "Debt", foreign_key: :to_user_id

  has_many :friendships_as_user_a,   class_name: "Friendship", foreign_key: :user_a_id
  has_many :friendships_as_user_b,   class_name: "Friendship", foreign_key: :user_b_id
  has_many :requested_friendships,   class_name: "Friendship", foreign_key: :requested_by_id

  after_create :assign_default_categories

  # Returns a Transaction relation scoped to transactions this user can see:
  # transactions they created, have a split on, are the settlee of, or that
  # belong to a group they're a member of.
  def visible_transactions
    Transaction
      .left_joins(:transaction_splits)
      .where(
        "transactions.user_id = :uid OR transaction_splits.user_id = :uid " \
        "OR transactions.settles_user_id = :uid OR transactions.group_id IN (:group_ids)",
        uid: id, group_ids: group_ids.presence || [ 0 ]
      )
      .distinct
  end

  def preferred_account
    default_account || accounts.first
  end

  def admin?
    role == "admin"
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at email full_name id mobile_number role updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  private

  def assign_default_categories
    Categories::AssignDefaults.call(self)
  end
end

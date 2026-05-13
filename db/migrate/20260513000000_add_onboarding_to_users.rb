class AddOnboardingToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :onboarding, :boolean, null: false, default: false
  end
end

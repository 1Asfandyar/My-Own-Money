class RenameOnboardingToOnboardingCompletedOnUsers < ActiveRecord::Migration[8.0]
  def change
    rename_column :users, :onboarding, :onboarding_completed
  end
end

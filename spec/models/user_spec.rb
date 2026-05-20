require 'rails_helper'

RSpec.describe User, type: :model do
  describe "default categories" do
    it "assigns predefined categories after create" do
      user = create(:user)

      expect(user.categories.count).to eq(Categories::Defaults.all.size)
      expect(user.categories.pluck(:name)).to include("Groceries", "Salary", "Other")
    end

    it "does not duplicate defaults when assignment runs again" do
      user = create(:user)

      Categories::AssignDefaults.call(user)

      expect(user.categories.count).to eq(Categories::Defaults.all.size)
    end

    it "does not overwrite existing category metadata" do
      user = create(:user)
      category = user.categories.find_by!(name: "Groceries")
      category.update!(icon: "custom_icon", color: "#123456")

      Categories::AssignDefaults.call(user)

      expect(category.reload.icon).to eq("custom_icon")
      expect(category.color).to eq("#123456")
    end
  end
end

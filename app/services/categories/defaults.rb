module Categories
  module Defaults
    EXPENSE = [
      { name: "Groceries", icon: "shopping_cart", color: "#FF6B6B" },
      { name: "Fuel", icon: "local_gas_station", color: "#4ECDC4" },
      { name: "Public Transport", icon: "directions_bus", color: "#45B7D1" },
      { name: "Car Maintenance", icon: "build", color: "#2C9E8F" },
      { name: "Bills & Utilities", icon: "power", color: "#FFD93D" },
      { name: "Shopping", icon: "checkroom", color: "#9D4EDD" },
      { name: "Entertainment", icon: "theaters", color: "#FF006E" },
      { name: "Health", icon: "medication", color: "#F1FAEE" },
      { name: "Education", icon: "school", color: "#1D3557" },
      { name: "Personal Care", icon: "self_care", color: "#003049" },
      { name: "Charity & Donations", icon: "volunteer_activism", color: "#DC143C" },
      { name: "Other", icon: "category", color: "#808080" }
    ].freeze

    INCOME = [
      { name: "Salary", icon: "work", color: "#06A77D" },
      { name: "Other Income", icon: "category", color: "#808080" }
    ].freeze

    module_function

    def all
      expense + income
    end

    def expense
      EXPENSE.map { |attributes| attributes.merge(category_type: :expense) }
    end

    def income
      INCOME.map { |attributes| attributes.merge(category_type: :income) }
    end
  end
end

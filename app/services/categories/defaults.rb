module Categories
  module Defaults
    EXPENSE = [
      { name: "Groceries", icon: "shopping_cart", color: "#FF6B6B" },
      { name: "Restaurants & Dining", icon: "restaurant", color: "#FF8C42" },
      { name: "Coffee & Snacks", icon: "local_cafe", color: "#FFA366" },
      { name: "Food Delivery", icon: "two_wheeler", color: "#FFB84D" },
      { name: "Fuel", icon: "local_gas_station", color: "#4ECDC4" },
      { name: "Public Transport", icon: "directions_bus", color: "#45B7D1" },
      { name: "Taxi/Uber", icon: "local_taxi", color: "#3BA39C" },
      { name: "Car Maintenance", icon: "build", color: "#2C9E8F" },
      { name: "Parking", icon: "local_parking", color: "#1F8A7A" },
      { name: "Electricity", icon: "power", color: "#FFD93D" },
      { name: "Water", icon: "water_drop", color: "#6BCB77" },
      { name: "Internet/Phone Bill", icon: "phone", color: "#4D96FF" },
      { name: "Gas Bill", icon: "local_fire_department", color: "#FF6B35" },
      { name: "Clothing", icon: "checkroom", color: "#9D4EDD" },
      { name: "Shoes", icon: "checkroom", color: "#C77DFF" },
      { name: "Electronics", icon: "devices", color: "#E0AAFF" },
      { name: "Home Appliances", icon: "home", color: "#B5A7FF" },
      { name: "Books & Media", icon: "menu_book", color: "#9D84B7" },
      { name: "Movies & Shows", icon: "theaters", color: "#FF006E" },
      { name: "Gaming", icon: "sports_esports", color: "#FB5607" },
      { name: "Sports & Hobbies", icon: "sports", color: "#FFBE0B" },
      { name: "Music & Concerts", icon: "music_note", color: "#8338EC" },
      { name: "Medical & Doctor", icon: "medical_services", color: "#E63946" },
      { name: "Medicines", icon: "medication", color: "#F1FAEE" },
      { name: "Gym & Fitness", icon: "fitness_center", color: "#A8DADC" },
      { name: "Health Insurance", icon: "health_and_safety", color: "#457B9D" },
      { name: "Tuition/Courses", icon: "school", color: "#1D3557" },
      { name: "School Supplies", icon: "edit", color: "#F77F00" },
      { name: "Hotels", icon: "hotel", color: "#06A77D" },
      { name: "Flight Tickets", icon: "flight", color: "#118AB2" },
      { name: "Travel", icon: "card_travel", color: "#073B4C" },
      { name: "Streaming Services", icon: "tv", color: "#D62828" },
      { name: "Software/Apps", icon: "computer", color: "#F77F00" },
      { name: "Subscriptions", icon: "subscriptions", color: "#FCBF49" },
      { name: "Haircut & Salon", icon: "spa", color: "#EAE2B7" },
      { name: "Personal Care", icon: "self_care", color: "#003049" },
      { name: "Insurance", icon: "shield", color: "#669BBC" },
      { name: "Loan Repayment", icon: "credit_card", color: "#003049" },
      { name: "Gifts", icon: "card_giftcard", color: "#FF69B4" },
      { name: "Charity & Donations", icon: "volunteer_activism", color: "#DC143C" },
      { name: "Other", icon: "category", color: "#808080" }
    ].freeze

    INCOME = [
      { name: "Salary", icon: "work", color: "#06A77D" },
      { name: "Freelance/Gig Work", icon: "code", color: "#118AB2" },
      { name: "Bonus", icon: "celebration", color: "#073B4C" },
      { name: "Investment Returns", icon: "trending_up", color: "#5C9E9E" },
      { name: "Rental Income", icon: "apartment", color: "#4A6FA5" },
      { name: "Business Income", icon: "business", color: "#2E6F95" },
      { name: "Side Hustle", icon: "rocket", color: "#0D47A1" },
      { name: "Gift/Allowance", icon: "card_giftcard", color: "#1565C0" },
      { name: "Refund", icon: "assignment_return", color: "#1976D2" },
      { name: "Interest/Dividends", icon: "monetization_on", color: "#1E88E5" },
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

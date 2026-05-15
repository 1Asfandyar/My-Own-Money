FactoryBot.define do
  factory :category do
    name          { Faker::Commerce.department(max: 1) }
    category_type { :expense }
    icon          { nil }
    color         { nil }
    association :user
  end
end

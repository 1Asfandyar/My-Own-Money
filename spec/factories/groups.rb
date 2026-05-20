FactoryBot.define do
  factory :group do
    sequence(:name) { |n| "Group #{n}" }
    description { "A test group" }
    association :created_by, factory: :user
  end

  factory :groups_user do
    association :group
    association :user
  end
end

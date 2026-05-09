FactoryBot.define do
  factory :account do
    sequence(:name) { |n| "Account #{n}" }
    current_balance_cents { 0 }
    initial_balance_cents { 0 }
    is_archived { false }
    association :user
    association :currency
  end
end

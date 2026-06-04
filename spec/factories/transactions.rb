FactoryBot.define do
  factory :transaction do
    sequence(:title) { |n| "Transaction #{n}" }
    amount_cents     { 1000 }
    transaction_type { :expense }
    visibility_type  { :personal }
    transaction_date { Time.current }
    association :user
    association :account
    association :currency

    trait :transfer do
      transaction_type { :transfer }
      association :transfer_account, factory: :account
    end

    trait :shared do
      visibility_type { :shared }
      association :group
    end

    trait :settlement do
      transaction_type { :settlement }
      visibility_type  { :personal }
      association :settles_user, factory: :user
    end
  end
end

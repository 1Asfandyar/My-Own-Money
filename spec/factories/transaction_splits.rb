FactoryBot.define do
  factory :transaction_split do
    split_method      { :equal }
    owed_amount_cents { 500 }
    association :financial_transaction, factory: :transaction
    association :user
  end
end

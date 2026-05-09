FactoryBot.define do
  factory :currency do
    sequence(:code) { |n| "C#{n.to_s.rjust(2, '0')}" }
    sequence(:name) { |n| "Currency #{n}" }
    symbol { "$" }
  end
end

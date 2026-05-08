FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "Password1!" }
    full_name { "Test User" }
    sequence(:mobile_number) { |n| "0300000#{n.to_s.rjust(4, '0')}" }
    role { :user }

    trait :admin do
      role { :admin }
    end
  end
end

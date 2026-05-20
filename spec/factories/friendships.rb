FactoryBot.define do
  factory :friendship do
    transient do
      sender   { create(:user) }
      receiver { create(:user) }
    end

    status { :pending }

    after(:build) do |friendship, evaluator|
      sorted = [ evaluator.sender, evaluator.receiver ].sort_by(&:id)
      friendship.user_a        = sorted[0]
      friendship.user_b        = sorted[1]
      friendship.requested_by  = evaluator.sender
    end

    trait :accepted do
      status { :accepted }
    end

    trait :blocked do
      status { :blocked }
    end
  end
end

module Api::V0
  class FriendshipSerializer < Blueprinter::Base
    identifier :id

    fields :status, :requested_by_id, :created_at, :updated_at

    association :user_a, blueprint: Api::V0::UserSerializer
    association :user_b, blueprint: Api::V0::UserSerializer
  end
end

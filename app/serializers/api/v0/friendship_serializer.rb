module Api::V0
  class FriendshipSerializer < Blueprinter::Base
    identifier :id

    fields :status, :requested_by_id, :created_at, :updated_at

    field :friend do |friendship, options|
      current_user = options[:current_user]
      other = friendship.other_user(current_user)
      Api::V0::UserSerializer.render_as_hash(other)
    end

    field :balance do |friendship, options|
      current_user_id = options[:current_user_id]
      debt_map        = options[:debt_map] || {}
      friend_id       = friendship.user_a_id == current_user_id ? friendship.user_b_id : friendship.user_a_id
      debt            = debt_map[friend_id]

      if debt.nil?
        { type: "settled_up", amount_cents: 0 }
      elsif debt.from_user_id == current_user_id
        { type: "you_owe", amount_cents: debt.amount_cents }
      else
        { type: "owes_you", amount_cents: debt.amount_cents }
      end
    end
  end
end

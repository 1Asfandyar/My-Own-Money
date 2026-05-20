# frozen_string_literal: true

module Friendships
  class BalanceSummary < ApplicationService
    def call(current_user_id:, friend_id:)
      debt = Debt
        .where(from_user_id: current_user_id, to_user_id: friend_id)
        .or(Debt.where(from_user_id: friend_id, to_user_id: current_user_id))
        .first

      result = if debt.nil?
        { type: "settled_up", amount_cents: 0 }
      elsif debt.from_user_id == current_user_id
        { type: "you_owe", amount_cents: debt.amount_cents }
      else
        { type: "owes_you", amount_cents: debt.amount_cents }
      end

      Success(result)
    end
  end
end

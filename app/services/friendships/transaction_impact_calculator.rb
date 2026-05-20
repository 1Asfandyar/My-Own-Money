# frozen_string_literal: true

module Friendships
  # Determines the bilateral financial impact of a single transaction between two users.
  # Expects transaction.transaction_splits to be preloaded.
  #
  # Impact types from current_user perspective:
  #   you_lent     — current_user paid; friend's share is what friend owes
  #   you_borrowed — friend paid; current_user's share is what current_user owes
  #   no_balance   — a third party paid; no direct debt between the two users
  class TransactionImpactCalculator < ApplicationService
    def call(transaction:, current_user_id:, friend_id:)
      splits_by_user = transaction.transaction_splits.index_by(&:user_id)

      impact = if transaction.user_id == current_user_id
        amount = splits_by_user[friend_id]&.owed_amount_cents || 0
        { type: "you_lent", amount_cents: amount }
      elsif transaction.user_id == friend_id
        amount = splits_by_user[current_user_id]&.owed_amount_cents || 0
        { type: "you_borrowed", amount_cents: amount }
      else
        { type: "no_balance", amount_cents: 0 }
      end

      Success(impact)
    end
  end
end

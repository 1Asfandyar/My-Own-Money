# frozen_string_literal: true

module Friendships
  # Returns all shared transactions in which both users appear as split participants,
  # ordered newest-first. Uses subquery intersection to avoid N+1 on the splits table.
  class ActivityQuery < ApplicationService
    def call(current_user_id:, friend_id:)
      current_user_tx_ids = TransactionSplit.where(user_id: current_user_id).select(:transaction_id)
      friend_tx_ids       = TransactionSplit.where(user_id: friend_id).select(:transaction_id)

      transactions = Transaction
        .shared
        .where(id: current_user_tx_ids)
        .where(id: friend_tx_ids)
        .includes(:group, :user, :transaction_splits)
        .order(transaction_date: :desc)

      Success(transactions)
    end
  end
end

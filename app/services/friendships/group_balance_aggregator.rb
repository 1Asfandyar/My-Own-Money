# frozen_string_literal: true

module Friendships
  # Computes per-group net balances between two users derived from transaction_splits.
  # Only groups where BOTH users are members are considered.
  # Only groups with a non-zero net balance are included in the result.
  class GroupBalanceAggregator < ApplicationService
    def call(current_user_id:, friend_id:)
      common_group_ids = GroupsUser
        .where(user_id: current_user_id)
        .where(group_id: GroupsUser.select(:group_id).where(user_id: friend_id))
        .pluck(:group_id)

      return Success([]) if common_group_ids.empty?

      groups = Group.where(id: common_group_ids).index_by(&:id)

      # Sum of friend's splits on transactions where current_user paid (friend owes current_user)
      friend_owes_by_group = TransactionSplit
        .joins(:financial_transaction)
        .where(user_id: friend_id)
        .where(transactions: { user_id: current_user_id, group_id: common_group_ids, visibility_type: :shared })
        .group("transactions.group_id")
        .sum(:owed_amount_cents)

      # Sum of current_user's splits on transactions where friend paid (current_user owes friend)
      current_owes_by_group = TransactionSplit
        .joins(:financial_transaction)
        .where(user_id: current_user_id)
        .where(transactions: { user_id: friend_id, group_id: common_group_ids, visibility_type: :shared })
        .group("transactions.group_id")
        .sum(:owed_amount_cents)

      balances = common_group_ids.filter_map do |group_id|
        net = (friend_owes_by_group[group_id] || 0) - (current_owes_by_group[group_id] || 0)
        next if net.zero?

        {
          group_id: group_id,
          group_name: groups[group_id].name,
          balance: net_to_balance(net)
        }
      end

      Success(balances)
    end

    private

    def net_to_balance(net)
      if net > 0
        { type: "owes_you", amount_cents: net }
      else
        { type: "you_owe", amount_cents: net.abs }
      end
    end
  end
end

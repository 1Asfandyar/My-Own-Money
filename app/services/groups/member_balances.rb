# frozen_string_literal: true

module Groups
  # Computes viewer-relative balance data for every pair of members in a group.
  #
  # per_member: ALL pairwise net balances (non-zero only). Direction is always
  #   "from_user owes to_user". is_you flags the current viewer on either side.
  # overall:    the current viewer's aggregate net position across all pairs.
  #
  # Source: transaction_splits on shared expenses only. Settlements (personal
  # visibility) are excluded, consistent with Friendships::GroupBalanceAggregator.
  class MemberBalances < ApplicationService
    def call(group_id:, current_user_id:)
      all_member_ids = GroupsUser.where(group_id: group_id).pluck(:user_id)
      return Success(empty_result) if all_member_ids.size <= 1

      users = User.where(id: all_member_ids).index_by(&:id)

      # For every (participant, payer) pair in this group, sum owed_amount_cents.
      # Excludes the payer's own split (ts.user_id != t.user_id).
      raw = TransactionSplit
        .joins(:financial_transaction)
        .where(transactions: { group_id: group_id, visibility_type: :shared })
        .where.not("transaction_splits.user_id = transactions.user_id")
        .group("transaction_splits.user_id", "transactions.user_id")
        .pluck(
          "transaction_splits.user_id",
          "transactions.user_id",
          "SUM(transaction_splits.owed_amount_cents)"
        )

      # debts[a][b] = gross amount a owes b before netting
      debts = Hash.new { |h, k| h[k] = Hash.new(0) }
      raw.each { |participant, payer, amount| debts[participant][payer] += amount }

      overall_net = 0
      per_member = all_member_ids.combination(2).filter_map do |a, b|
        net = debts[a][b] - debts[b][a]
        next if net.zero?

        from_id, to_id, amount = net > 0 ? [ a, b, net ] : [ b, a, -net ]

        overall_net += amount  if to_id   == current_user_id
        overall_net -= amount  if from_id == current_user_id

        {
          from_user:    build_user(users[from_id], current_user_id),
          to_user:      build_user(users[to_id],   current_user_id),
          amount_cents: amount
        }
      end

      Success(overall: net_to_balance(overall_net), per_member: per_member)
    end

    private

    def build_user(user, current_user_id)
      { id: user.id, name: user.full_name, is_you: user.id == current_user_id }
    end

    def net_to_balance(net)
      if net > 0
        { type: "owes_you", amount_cents: net }
      elsif net < 0
        { type: "you_owe", amount_cents: net.abs }
      else
        { type: "settled_up", amount_cents: 0 }
      end
    end

    def empty_result
      { overall: { type: "settled_up", amount_cents: 0 }, per_member: [] }
    end
  end
end

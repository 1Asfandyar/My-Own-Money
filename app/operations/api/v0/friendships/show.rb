# frozen_string_literal: true

module Api::V0::Friendships
  class Show
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:id).filled(:integer)
      end
    end

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      return Failure(:not_found) unless friendship

      friend = friendship.other_user(current_user)

      balance_summary  = yield Friendships::BalanceSummary.call(current_user_id: current_user.id, friend_id: friend.id)
      group_balances   = yield Friendships::GroupBalanceAggregator.call(current_user_id: current_user.id, friend_id: friend.id)
      raw_transactions = yield Transaction::Query.call(current_user: current_user, friend_id: friend.id, visibility_type: "shared", per_page: nil)
      transactions     = yield Transaction::Formatter.call(raw_transactions, current_user_id: current_user.id)

      Success(
        success: true,
        friendship: {
          id:               friendship.id,
          status:           friendship.status,
          requested_by_id:  friendship.requested_by_id,
          created_at:       friendship.created_at,
          updated_at:       friendship.updated_at,
          friend:           serialize_user(friend),
          balance_summary:  balance_summary,
          group_balances:   group_balances,
          transactions:     transactions
        }
      )
    end

    private

    attr_reader :current_user, :params

    def friendship
      @friendship ||= begin
        f = Friendship.includes(:user_a, :user_b).find_by(id: params[:id])
        f&.involves?(current_user) ? f : nil
      end
    end

    def serialize_user(user)
      { id: user.id, full_name: user.full_name, email: user.email }
    end
  end
end

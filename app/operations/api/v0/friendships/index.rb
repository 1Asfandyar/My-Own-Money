module Api::V0::Friendships
  class Index
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        optional(:filter).maybe(:string)
        optional(:status).maybe(:string)
      end

      rule(:filter) do
        next if value.nil?
        key.failure("must be one of: incoming, outgoing") unless %w[incoming outgoing].include?(value)
      end

      rule(:status) do
        next if value.nil?
        key.failure("must be one of: pending, accepted, blocked") unless %w[pending accepted blocked].include?(value)
      end
    end

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      Success(
        success: true,
        friendships: Api::V0::FriendshipSerializer.render_as_hash(friendships)
      )
    end

    private

    attr_reader :current_user, :params

    def friendships
      scope = Friendship
        .where("user_a_id = ? OR user_b_id = ?", current_user.id, current_user.id)
        .includes(:user_a, :user_b)

      scope = apply_status_filter(scope)
      scope = apply_direction_filter(scope)
      scope
    end

    def apply_status_filter(scope)
      if params[:status].present?
        scope.where(status: params[:status])
      elsif params[:filter].present?
        scope.where(status: :pending)
      else
        scope.where(status: :accepted)
      end
    end

    def apply_direction_filter(scope)
      case params[:filter]
      when "incoming" then scope.where.not(requested_by_id: current_user.id)
      when "outgoing" then scope.where(requested_by_id: current_user.id)
      else scope
      end
    end
  end
end

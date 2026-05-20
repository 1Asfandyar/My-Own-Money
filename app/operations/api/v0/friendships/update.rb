module Api::V0::Friendships
  class Update
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:id).filled(:integer)
        required(:status).filled(:string)
      end

      rule(:status) do
        key.failure("must be one of: accepted, blocked, rejected") unless %w[accepted blocked rejected].include?(value)
      end
    end

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      return Failure(:not_found) unless friendship
      yield authorize_transition
      yield apply_update

      if params[:status] == "rejected"
        Success(success: true)
      else
        Success(success: true, friendship: Api::V0::FriendshipSerializer.render_as_hash(friendship, current_user: current_user, current_user_id: current_user.id))
      end
    end

    private

    attr_reader :current_user, :params, :friendship

    def friendship
      @friendship ||= begin
        f = Friendship.find_by(id: params[:id])
        f&.involves?(current_user) ? f : nil
      end
    end

    def authorize_transition
      case params[:status]
      when "accepted", "rejected"
        return Failure(:forbidden) unless friendship.pending?
        return Failure(:forbidden) if friendship.requested_by_id == current_user.id

        Success()
      when "blocked"
        Success()
      end
    end

    def apply_update
      if params[:status] == "rejected"
        friendship.destroy ? Success() : Failure(errors: friendship.errors.to_hash)
      else
        friendship.update(status: params[:status]) ? Success() : Failure(errors: friendship.errors.to_hash)
      end
    end
  end
end

module Api::V0::Friendships
  class Destroy
    include Api::V0::ApplicationOperation

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      return Failure(:not_found) unless friendship
      return Failure(:forbidden) unless can_destroy?

      friendship.destroy
      Success(success: true)
    end

    private

    attr_reader :current_user, :params

    def friendship
      @friendship ||= begin
        f = Friendship.find_by(id: params[:id])
        f&.involves?(current_user) ? f : nil
      end
    end

    def can_destroy?
      friendship.requested_by_id == current_user.id && friendship.pending?
    end
  end
end

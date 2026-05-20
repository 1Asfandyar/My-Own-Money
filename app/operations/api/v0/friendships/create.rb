module Api::V0::Friendships
  class Create
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:user_ids).filled(:array).each(:integer)
      end
    end

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      yield validate_users
      yield persist

      Success(
        success: true,
        friendships: Api::V0::FriendshipSerializer.render_as_hash(@friendships)
      )
    end

    private

    attr_reader :current_user, :params

    def validate_users
      target_ids = params[:user_ids].uniq.reject { |id| id == current_user.id }
      found_count = User.where(id: target_ids).count

      if found_count != target_ids.size
        return Failure(errors: { user_ids: [ "one or more users do not exist" ] })
      end

      @target_ids = target_ids
      Success()
    end

    def persist
      @friendships = []

      @target_ids.each do |user_id|
        user_a_id, user_b_id = [ current_user.id, user_id ].minmax

        friendship = Friendship.find_or_initialize_by(user_a_id: user_a_id, user_b_id: user_b_id)
        next unless friendship.new_record?

        friendship.requested_by_id = current_user.id
        friendship.status = :pending
        friendship.save!
        @friendships << friendship
      end

      Success()
    rescue ActiveRecord::RecordInvalid => e
      Failure(errors: { base: [ e.message ] })
    end
  end
end

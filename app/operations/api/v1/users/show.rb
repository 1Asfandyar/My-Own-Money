module Api::V1::Users
  class Show
    include Api::V1::ApplicationOperation

    class Contract < Api::V1::ApplicationContract
      params do
        required(:id).filled(:integer)
      end
    end

    def call(params, current_user:)
      params = yield validate_contract(params.slice(:id))
      @current_user = current_user
      @user = User.find_by(id: params[:id])

      return Failure(:not_found) unless user

      yield authorize

      Success(success: true, user: Api::V1::UserSerializer.render_as_hash(user))
    end

    private

    attr_reader :current_user, :user

    def authorize
      UserPolicy.new(current_user, user).show? ? Success() : Failure(:forbidden)
    end
  end
end

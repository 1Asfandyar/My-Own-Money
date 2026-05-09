module Api::V0::Users
  class Destroy
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
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

      user.destroy
      Success(success: true, message: "User deleted")
    end

    private

    attr_reader :current_user, :user

    def authorize
      UserPolicy.new(current_user, user).destroy? ? Success() : Failure(:forbidden)
    end
  end
end

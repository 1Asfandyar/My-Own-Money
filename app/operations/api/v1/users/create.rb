module Api::V1::Users
  class Create
    include Api::V1::ApplicationOperation

    class Contract < Api::V1::ApplicationContract
      params do
        required(:email).filled(:string)
        required(:password).filled(:string)
        required(:password_confirmation).filled(:string)
        optional(:role).maybe(:string)
      end

      rule(:email).validate(:email_format)
    end

    def call(params, current_user:)
      params = yield validate_contract(user_params(params))
      @current_user = current_user
      @user = User.new(params.slice(:email, :password, :password_confirmation, :role))

      yield authorize
      yield save_user

      Success(success: true, user: Api::V1::UserSerializer.render_as_hash(user))
    end

    private

    attr_reader :current_user, :user

    def user_params(params)
      params.fetch(:user, params.fetch("user", {}))
    end

    def authorize
      UserPolicy.new(current_user, user).create? ? Success() : Failure(:forbidden)
    end

    def save_user
      user.save ? Success(user) : Failure(errors: user.errors.to_hash)
    end
  end
end

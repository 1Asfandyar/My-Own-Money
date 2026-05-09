module Api::V0::Users
  class Update
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:id).filled(:integer)
        optional(:email).filled(:string)
        optional(:password).filled(:string)
        optional(:password_confirmation).filled(:string)
        optional(:role).maybe(:string)
      end

      rule(:email).validate(:email_format)
    end

    def call(params, current_user:)
      params = yield validate_contract(params_for_contract(params))
      @current_user = current_user
      @user = User.find_by(id: params[:id])
      @attributes = params.except(:id)

      return Failure(:not_found) unless user

      yield authorize
      yield update_user

      Success(success: true, user: Api::V0::UserSerializer.render_as_hash(user))
    end

    private

    attr_reader :attributes, :current_user, :user

    def params_for_contract(params)
      params.fetch(:user, params.fetch("user", {})).merge(id: params[:id] || params["id"])
    end

    def authorize
      UserPolicy.new(current_user, user).update? ? Success() : Failure(:forbidden)
    end

    def update_user
      user.update(attributes) ? Success(user) : Failure(errors: user.errors.to_hash)
    end
  end
end

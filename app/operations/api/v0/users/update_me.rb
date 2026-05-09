module Api::V0::Users
  class UpdateMe
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        optional(:full_name).filled(:string)
        optional(:mobile_number).filled(:string)
        optional(:email).filled(:string)
        optional(:password).filled(:string)
        optional(:password_confirmation).filled(:string)
      end

      rule(:email).validate(:email_format)
    end

    def call(params, current_user:)
      attributes = yield validate_contract(profile_params(params))

      yield update_user(current_user, attributes)

      Success(
        success: true,
        user: Api::V0::UserSerializer.render_as_hash(current_user)
      )
    end

    private

    def profile_params(params)
      params.fetch(:user, params.fetch("user", {}))
    end

    def update_user(user, attributes)
      user.update(attributes) ? Success(user) : Failure(errors: user.errors.to_hash)
    end
  end
end

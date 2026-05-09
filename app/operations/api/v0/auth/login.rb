module Api::V0::Auth
  class Login
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:email).filled(:string)
        required(:password).filled(:string)
      end

      rule(:email).validate(:email_format)
    end

    def call(params)
      params = yield validate_contract(login_params(params))
      user = User.find_for_authentication(email: params[:email])

      return Failure(:unauthorized) unless user&.valid_password?(params[:password])

      Success(auth_payload(user))
    end

    private

    def login_params(params)
      params.fetch(:user, params.fetch("user", {}))
    end

    def auth_payload(user)
      token, payload = Warden::JWTAuth::UserEncoder.new.call(
        user,
        Api::V0::ApiController::JWT_SCOPE,
        Api::V0::ApiController::JWT_AUDIENCE
      )

      {
        success: true,
        token: token,
        authorization: "Bearer #{token}",
        expires_at: Time.zone.at(payload["exp"]),
        user: Api::V0::UserSerializer.render_as_hash(user)
      }
    end
  end
end

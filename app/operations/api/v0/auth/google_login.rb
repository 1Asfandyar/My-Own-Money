module Api::V0::Auth
  class GoogleLogin
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:token).filled(:string)
      end
    end

    def call(params)
      @params = params

      payload = verify_google_token
      return Failure(errors: { base: ["invalid_token"] }) unless payload
      return Failure(errors: { base: ["email_not_verified"] }) unless payload["email_verified"]

      user = find_or_create_user(payload)
      return Failure(:user_creation_failed) unless user&.persisted?

      Success(auth_payload(user))
    end

    private
    attr_reader :params

    def verify_google_token
      validator = GoogleIDToken::Validator.new
      validator.check(params[:token], ENV["GOOGLE_CLIENT_ID"])
    rescue GoogleIDToken::ValidationError => e
      Rails.logger.error("Google token validation failed: #{e.message}")
      nil
    end

    def find_or_create_user(payload)
      user = User.find_or_initialize_by(email: payload["email"])
      user.assign_attributes(uid: payload["sub"], provider: "google", full_name: payload["name"])
      user.password = SecureRandom.hex(10) if user.new_record?
      user.save ? user : nil
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

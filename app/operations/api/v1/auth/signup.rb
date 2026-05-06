module Api
  module V1
    module Auth
      class Signup
        include Api::V1::ApplicationOperation

        class Contract < Api::V1::ApplicationContract
          params do
            required(:full_name).filled(:string)
            required(:mobile_number).filled(:string)
            required(:email).filled(:string)
            required(:password).filled(:string)
            optional(:password_confirmation).maybe(:string)
          end

          rule(:email).validate(:email_format)
        end

        def call(params)
          params = yield validate_contract(user_params(params))
          user = User.new(params.slice(:full_name, :mobile_number, :email, :password, :password_confirmation))

          yield save_user(user)

          Success(auth_payload(user))
        end

        private

        def user_params(params)
          params.fetch(:user, params.fetch('user', {}))
        end

        def save_user(user)
          user.save ? Success(user) : Failure(errors: user.errors.to_hash)
        end

        def auth_payload(user)
          token, payload = Warden::JWTAuth::UserEncoder.new.call(
            user,
            Api::V1::ApiController::JWT_SCOPE,
            Api::V1::ApiController::JWT_AUDIENCE
          )

          {
            success: true,
            token: token,
            authorization: "Bearer #{token}",
            expires_at: Time.zone.at(payload['exp']),
            user: Api::V1::UserSerializer.render_as_hash(user, view: :show)
          }
        end
      end
    end
  end
end

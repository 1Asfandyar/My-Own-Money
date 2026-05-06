module Api
  module V1
    module Users
      class UpdateMe
        include Api::V1::ApplicationOperation

        class Contract < Api::V1::ApplicationContract
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
            user: Api::V1::UserSerializer.render_as_hash(current_user, view: :show)
          )
        end

        private

        def profile_params(params)
          params.fetch(:user, params.fetch('user', {}))
        end

        def update_user(user, attributes)
          user.update(attributes) ? Success(user) : Failure(errors: user.errors.to_hash)
        end
      end
    end
  end
end

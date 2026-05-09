module Api::V0
  class AuthController < ApiController
    skip_before_action :require_current_user!

    def signup
      Api::V0::Auth::Signup.call(params.to_unsafe_h) do |result|
        result.success { |data| authenticated_response(data, :created) }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    def login
      Api::V0::Auth::Login.call(params.to_unsafe_h) do |result|
        result.success { |data| authenticated_response(data, :ok) }
        result.failure(:unauthorized) { unauthorized_response("Invalid email or password") }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    def logout
      Api::V0::Auth::Logout.call(token: bearer_token) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure(:unauthorized) { unauthorized_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    private

    def authenticated_response(data, status)
      response.set_header("Authorization", data.delete(:authorization))
      render json: data, status: status
    end
  end
end

module Api::V1
  class AuthController < ApiController
    def signup
      Api::V1::Auth::Signup.call(params.to_unsafe_h) do |result|
        result.success { |data| authenticated_response(data, :created) }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    def login
      Api::V1::Auth::Login.call(params.to_unsafe_h) do |result|
        result.success { |data| authenticated_response(data, :ok) }
        result.failure(:unauthorized) { unauthorized_response("Invalid email or password") }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    def logout
      Api::V1::Auth::Logout.call(token: bearer_token) do |result|
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

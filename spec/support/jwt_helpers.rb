# Convenience helpers for authenticating requests in specs.
#
# Usage in a request spec:
#   let(:user) { create(:user) }
#
#   it "returns profile" do
#     get "/api/v0/me", headers: auth_headers(user)
#     expect(response).to have_http_status(:ok)
#   end

module JwtHelpers
  def jwt_token_for(user)
    payload = {
      sub:  user.id.to_s,
      scp:  "user",
      jti:  SecureRandom.uuid,
      iat:  Time.current.to_i,
      exp:  1.day.from_now.to_i
    }
    secret = Rails.application.secret_key_base
    JWT.encode(payload, secret, "HS256")
  end

  def auth_headers(user)
    { "Authorization" => "Bearer #{jwt_token_for(user)}" }
  end
end

RSpec.configure do |config|
  config.include JwtHelpers, type: :request
end

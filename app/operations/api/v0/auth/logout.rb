module Api::V0::Auth
  class Logout
    include Api::V0::ApplicationOperation

    def call(_params = {}, token:)
      return Failure(:unauthorized) if token.blank?

      Warden::JWTAuth::TokenRevoker.new.call(token)

      Success(success: true, message: "Logged out successfully")
    rescue JWT::DecodeError
      Failure(:unauthorized)
    end
  end
end

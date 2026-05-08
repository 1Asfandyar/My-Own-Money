module Api::V1
  class ApiController < ActionController::API
    include Apipie::DSL
    include Pundit::Authorization

    JWT_SCOPE = :user
    JWT_AUDIENCE = nil

    rescue_from ActiveRecord::RecordNotFound, with: :not_found_response
    rescue_from Pundit::NotAuthorizedError, with: :forbidden_response
    rescue_from StandardError, with: :handle_standard_error

    private

    def authenticate_user!
      unauthorized_response unless current_user
    end

    def require_current_user!
      authenticate_user!
    end

    def current_user
      return @current_user if defined?(@current_user)

      @current_user = decode_current_user
    end

    def unauthorized_response(message = "You are unauthorized to view this resource")
      render json: error_payload(message), status: :unauthorized
    end

    def forbidden_response(message = "You do not have access to perform this action")
      render json: error_payload(message), status: :forbidden
    end

    def not_found_response(message = "The requested resource does not exist")
      render json: error_payload(message), status: :not_found
    end

    def unprocessable_entity(errors)
      render json: normalize_errors(errors), status: :unprocessable_entity
    end

    def handle_standard_error(exception)
      Rails.logger.error(exception.full_message)
      render json: error_payload("Something went wrong"), status: :internal_server_error
    end

    def error_payload(message)
      { errors: [ { base: [ message ] } ] }
    end

    def normalize_errors(errors)
      return errors if errors.is_a?(Hash) && errors.key?(:errors)

      { errors: Array(errors) }
    end

    def decode_current_user
      token = bearer_token
      return nil if token.blank?

      Warden::JWTAuth::UserDecoder.new.call(token, JWT_SCOPE, JWT_AUDIENCE)
    rescue JWT::DecodeError,
           Warden::JWTAuth::Errors::RevokedToken,
           Warden::JWTAuth::Errors::NilUser,
           Warden::JWTAuth::Errors::WrongScope,
           Warden::JWTAuth::Errors::WrongAud => exception
      Rails.logger.debug { "JWT authentication failed: #{exception.class} - #{exception.message}" }
      nil
    end

    def bearer_token
      Warden::JWTAuth::HeaderParser.from_env(request.env) || token_from_authorization_header
    end

    def token_from_authorization_header
      authorization = request.authorization.presence ||
                      request.headers["Authorization"].presence ||
                      request.env["HTTP_AUTHORIZATION"].presence

      return nil if authorization.blank?

      scheme, token = authorization.to_s.split(/\s+/, 2)
      scheme.casecmp("Bearer").zero? ? token : nil
    end
  end
end

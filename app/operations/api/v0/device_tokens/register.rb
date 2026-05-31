module Api::V0::DeviceTokens
  class Register
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:token).filled(:string)
        required(:platform).filled(:string)
      end

      rule(:platform) do
        key.failure("must be android or ios") unless %w[android ios].include?(value)
      end
    end

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      yield authorize?
      yield upsert

      Success(
        success: true,
        device_token: Api::V0::DeviceTokenSerializer.render_as_hash(@device_token)
      )
    end

    private

    attr_reader :params, :current_user, :device_token

    def authorize?
      DeviceTokenPolicy.new(current_user, DeviceToken.new).create? ? Success() : Failure(:forbidden)
    end

    def upsert
      @device_token = DeviceToken.find_or_initialize_by(token: params[:token])
      @device_token.assign_attributes(user: current_user, platform: params[:platform])
      @device_token.save ? Success(@device_token) : Failure(errors: @device_token.errors.to_hash)
    end
  end
end

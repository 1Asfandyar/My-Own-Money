module Api::V0::DeviceTokens
  class Unregister
    include Api::V0::ApplicationOperation

    def call(params, current_user:)
      @current_user = current_user
      @device_token = DeviceToken.find_by(id: params[:id])

      return Failure(:not_found) unless device_token

      yield authorize?

      device_token.destroy
      Success(success: true)
    end

    private

    attr_reader :current_user, :device_token

    def authorize?
      DeviceTokenPolicy.new(current_user, device_token).destroy? ? Success() : Failure(:forbidden)
    end
  end
end

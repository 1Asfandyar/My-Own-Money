module Api::V0
  class DeviceTokensController < ApiController
    resource_description do
      short "Device token management"
      description "Register and unregister FCM device tokens for push notifications."
      api_version "v0"
    end

    api :POST, "/v0/device_tokens", "Register a device token"
    description <<~DESC
      Registers an FCM device token for the authenticated user. If the token already
      exists it is re-associated with the current user (handles token reassignment).

      **TypeScript Types**

      ```typescript
      // Input
      type Body = {
        token: string;    // FCM registration token
        platform: "android" | "ios";
      };

      // Output
      type Response = {
        success: boolean;
        device_token: DeviceToken;
      };

      type DeviceToken = {
        id: number;
        token: string;
        platform: string;
        user_id: number;
        created_at: string;
        updated_at: string;
      };
      ```
    DESC
    param :token, String, required: true, description: "FCM registration token"
    param :platform, String, required: true, description: "Device platform: android or ios"
    error code: 401, desc: "Unauthorized"
    error code: 422, desc: "Validation errors"
    returns code: 201, desc: "Token registered"
    def create
      Api::V0::DeviceTokens::Register.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :created }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    api :DELETE, "/v0/device_tokens/:id", "Unregister a device token"
    description <<~DESC
      Removes a device token so the user stops receiving push notifications on that device.

      **TypeScript Types**

      ```typescript
      // Input
      type Params = { id: number };

      // Output
      type Response = { success: boolean };
      ```
    DESC
    param :id, Integer, required: true, description: "Device token ID"
    error code: 401, desc: "Unauthorized"
    error code: 403, desc: "Forbidden"
    error code: 404, desc: "Token not found"
    returns code: 200, desc: "Token removed"
    def destroy
      Api::V0::DeviceTokens::Unregister.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { render json: { success: true }, status: :ok }
        result.failure(:not_found) { not_found_response }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end
  end
end

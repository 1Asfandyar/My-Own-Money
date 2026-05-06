module Api
  module V1
    class UsersController < ApiController
      before_action :require_current_user!

      def me
        Api::V1::Users::Me.call(current_user: current_user) do |result|
          result.success { |data| render json: data, status: :ok }
          result.failure { |errors| unprocessable_entity(errors) }
        end
      end

      def update_me
        Api::V1::Users::UpdateMe.call(params.to_unsafe_h, current_user: current_user) do |result|
          result.success { |data| render json: data, status: :ok }
          result.failure { |errors| unprocessable_entity(errors) }
        end
      end
    end
  end
end

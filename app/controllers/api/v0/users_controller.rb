module Api::V0
  class UsersController < ApiController
    def me
      Api::V0::Users::Me.call(current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end

    def update_me
      Api::V0::Users::UpdateMe.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end
  end
end

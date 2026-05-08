module Api::V1
  class BaseController < ApiController
    before_action :authenticate_user!

    rescue_from ActiveRecord::RecordNotFound do |_exception|
      render json: { error: "Not found" }, status: :not_found
    end

    rescue_from StandardError do |exception|
      render json: { error: exception.message }, status: :internal_server_error
    end

    protected

    def json_response(data, status = 200)
      render json: data, status: status
    end
  end
end

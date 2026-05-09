module Api::V0
  class AdminUsersController < ApiController
    skip_before_action :require_current_user!, only: [ :create ]

    resource_description do
      short "Admin users management"
      description "Manage administrator accounts"
      api_version "v0"
    end

    api :GET, "/v0/admin_users", "List all admin users"
    def index
      authorize AdminUser
      @admin_users = AdminUser.all
      render json: @admin_users
    end

    api :GET, "/v0/admin_users/:id", "Get admin user details"
    param :id, Integer, required: true, description: "Admin user ID"
    def show
      @admin_user = AdminUser.find(params[:id])
      authorize @admin_user
      render json: @admin_user
    end

    api :POST, "/v0/admin_users", "Create a new admin user"
    param :admin_user, Hash, required: true, description: "Admin user attributes" do
      param :email, String, required: true, description: "Admin email"
      param :password, String, required: true, description: "Admin password"
      param :password_confirmation, String, required: true, description: "Password confirmation"
    end
    def create
      @admin_user = AdminUser.new(admin_user_params)
      if @admin_user.save
        render json: @admin_user, status: :created
      else
        render json: { errors: @admin_user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    api :PATCH, "/v0/admin_users/:id", "Update admin user"
    param :id, Integer, required: true, description: "Admin user ID"
    param :admin_user, Hash, description: "Admin user attributes" do
      param :email, String, description: "Admin email"
      param :password, String, description: "Admin password"
    end
    def update
      @admin_user = AdminUser.find(params[:id])
      authorize @admin_user
      if @admin_user.update(admin_user_params)
        render json: @admin_user
      else
        render json: { errors: @admin_user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    api :DELETE, "/v0/admin_users/:id", "Delete admin user"
    param :id, Integer, required: true, description: "Admin user ID"
    def destroy
      @admin_user = AdminUser.find(params[:id])
      authorize @admin_user
      @admin_user.destroy
      render json: { message: "Admin user deleted" }
    end

    private

    def admin_user_params
      params.require(:admin_user).permit(:email, :password, :password_confirmation)
    end
  end
end

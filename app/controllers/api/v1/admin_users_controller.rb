module Api::V1
  class AdminUsersController < BaseController
    skip_before_action :authenticate_user!, only: [ :create ]

    resource_description do
      short "Admin users management"
      description "Manage administrator accounts"
      api_version "v1"
    end

    api :GET, "/v1/admin_users", "List all admin users"
    def index
      authorize AdminUser
      @admin_users = AdminUser.all
      json_response(@admin_users)
    end

    api :GET, "/v1/admin_users/:id", "Get admin user details"
    param :id, Integer, required: true, description: "Admin user ID"
    def show
      @admin_user = AdminUser.find(params[:id])
      authorize @admin_user
      json_response(@admin_user)
    end

    api :POST, "/v1/admin_users", "Create a new admin user"
    param :admin_user, Hash, required: true, description: "Admin user attributes" do
      param :email, String, required: true, description: "Admin email"
      param :password, String, required: true, description: "Admin password"
      param :password_confirmation, String, required: true, description: "Password confirmation"
    end
    def create
      @admin_user = AdminUser.new(admin_user_params)
      if @admin_user.save
        json_response(@admin_user, 201)
      else
        json_response({ errors: @admin_user.errors.full_messages }, 422)
      end
    end

    api :PATCH, "/v1/admin_users/:id", "Update admin user"
    param :id, Integer, required: true, description: "Admin user ID"
    param :admin_user, Hash, description: "Admin user attributes" do
      param :email, String, description: "Admin email"
      param :password, String, description: "Admin password"
    end
    def update
      @admin_user = AdminUser.find(params[:id])
      authorize @admin_user
      if @admin_user.update(admin_user_params)
        json_response(@admin_user)
      else
        json_response({ errors: @admin_user.errors.full_messages }, 422)
      end
    end

    api :DELETE, "/v1/admin_users/:id", "Delete admin user"
    param :id, Integer, required: true, description: "Admin user ID"
    def destroy
      @admin_user = AdminUser.find(params[:id])
      authorize @admin_user
      @admin_user.destroy
      json_response({ message: "Admin user deleted" })
    end

    private

    def admin_user_params
      params.require(:admin_user).permit(:email, :password, :password_confirmation)
    end
  end
end

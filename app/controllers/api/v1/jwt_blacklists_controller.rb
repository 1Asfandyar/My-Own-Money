module Api
  module V1
    class JwtBlacklistsController < BaseController
      resource_description do
        short "JWT token blacklist management"
        description "Manage JWT token revocation and blacklist"
        api_version "v1"
      end

      api :GET, "/v1/jwt_blacklists", "List all blacklisted JWT tokens"
      def index
        authorize JwtBlacklist
        @jwt_blacklists = JwtBlacklist.all
        json_response(@jwt_blacklists)
      end

      api :GET, "/v1/jwt_blacklists/:id", "Get JWT blacklist entry details"
      param :id, Integer, required: true, description: "Blacklist entry ID"
      def show
        @jwt_blacklist = JwtBlacklist.find(params[:id])
        authorize @jwt_blacklist
        json_response(@jwt_blacklist)
      end

      api :POST, "/v1/jwt_blacklists", "Create a new JWT blacklist entry"
      param :jwt_blacklist, Hash, required: true, description: "JWT blacklist attributes" do
        param :jti, String, required: true, description: "JWT ID (unique identifier)"
        param :exp, Integer, description: "Expiration timestamp (Unix time)"
      end
      def create
        authorize JwtBlacklist
        @jwt_blacklist = JwtBlacklist.new(jwt_blacklist_params)
        if @jwt_blacklist.save
          json_response(@jwt_blacklist, 201)
        else
          json_response({ errors: @jwt_blacklist.errors.full_messages }, 422)
        end
      end

      api :DELETE, "/v1/jwt_blacklists/:id", "Delete JWT blacklist entry"
      param :id, Integer, required: true, description: "Blacklist entry ID"
      def destroy
        @jwt_blacklist = JwtBlacklist.find(params[:id])
        authorize @jwt_blacklist
        @jwt_blacklist.destroy
        json_response({ message: "JWT blacklist entry deleted" })
      end

      private

      def jwt_blacklist_params
        params.require(:jwt_blacklist).permit(:jti, :exp)
      end
    end
  end
end

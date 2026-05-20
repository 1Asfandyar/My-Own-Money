module Api::V0::Groups
  class Index
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        optional(:kind).maybe(:string, included_in?: Group.kinds.keys)
      end
    end

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      Success(
        success: true,
        groups: Api::V0::GroupSerializer.render_as_hash(groups)
      )
    end

    private

    attr_reader :current_user, :params

    def groups
      scope = current_user.groups.includes(:groups_users, :users)

      if params[:kind] == "custom"
        scope.custom
      else
        scope.friends
      end
    end
  end
end

module Api::V0::Groups
  class Index
    include Api::V0::ApplicationOperation

    def call(params, current_user:)
      @current_user = current_user

      Success(
        success: true,
        groups: Api::V0::GroupSerializer.render_as_hash(groups)
      )
    end

    private

    attr_reader :current_user

    def groups
      current_user.groups.includes(:groups_users, :users)
    end
  end
end

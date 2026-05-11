module Api::V0::Groups
  class Index
    include Api::V0::ApplicationOperation

    def call(params, current_user:)
      groups = current_user.groups.includes(:groups_users, :users)
      Success(
        success: true,
        groups: Api::V0::GroupSerializer.render_as_hash(groups)
      )
    end
  end
end

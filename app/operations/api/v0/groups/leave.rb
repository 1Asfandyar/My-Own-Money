module Api::V0::Groups
  class Leave
    include Api::V0::ApplicationOperation

    def call(params, current_user:)
      @current_user = current_user
      @group        = current_user.groups.find_by(id: params[:id])

      return Failure(:not_found) unless group

      yield leave

      Success(success: true)
    end

    private

    attr_reader :current_user, :group

    def leave
      membership = GroupsUser.find_by(group: group, user: current_user)
      return Failure(errors: { base: [ "you are not a member of this group" ] }) unless membership

      return Failure(errors: { base: membership.errors.to_hash }) unless membership.destroy
      Success()
    end
  end
end

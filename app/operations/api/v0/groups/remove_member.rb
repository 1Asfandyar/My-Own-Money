module Api::V0::Groups
  class RemoveMember
    include Api::V0::ApplicationOperation

    def call(params, current_user:)
      @current_user = current_user
      @group        = current_user.groups.find_by(id: params[:id])

      return Failure(:not_found) unless group

      @target_user = User.find_by(id: params[:user_id])
      return Failure(:not_found) unless target_user

      yield remove

      Success(success: true)
    end

    private

    attr_reader :current_user, :group, :target_user

    def remove
      membership = GroupsUser.find_by(group: group, user: target_user)
      return Failure(errors: { user_id: [ "is not a member of this group" ] }) unless membership

      return Failure(errors: { base: membership.errors.to_hash }) unless membership.destroy
      Success()
    end
  end
end

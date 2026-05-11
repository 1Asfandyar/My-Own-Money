module Api::V0::Groups
  class AddMembers
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:id).filled(:integer)
        required(:user_ids).filled(:array).each(:integer)
      end
    end

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      @group = current_user.groups.find_by(id: params[:id])
      return Failure(:not_found) unless group

      yield validate_users
      yield add_members

      Success(
        success: true,
        group: Api::V0::GroupSerializer.render_as_hash(group)
      )
    end

    private

    attr_reader :params, :current_user, :group, :users_to_add

    def validate_users
      @users_to_add = User.where(id: params[:user_ids])
      if users_to_add.count != params[:user_ids].uniq.count
        return Failure(errors: { user_ids: [ "one or more users do not exist" ] })
      end

      Success()
    end

    def add_members
      users_to_add.each do |user|
        GroupsUser.find_or_create_by!(group: group, user: user)
      end
      Success()
    rescue ActiveRecord::RecordInvalid => e
      Failure(errors: { base: [ e.message ] })
    end
  end
end

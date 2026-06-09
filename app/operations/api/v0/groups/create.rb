module Api::V0::Groups
  class Create
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:name).filled(:string)
        optional(:description).maybe(:string)
        optional(:user_ids).maybe(:array).each(:integer)
      end
    end

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      yield validate_users if params[:user_ids].present?
      yield persist

      Success(
        success: true,
        group: Api::V0::GroupSerializer.render_as_hash(group)
      )
    end

    private

    attr_reader :current_user, :params, :group, :users_to_add

    def validate_users
      @users_to_add = User.where(id: params[:user_ids])
      if users_to_add.count != params[:user_ids].uniq.count
        return Failure(errors: { user_ids: [ "one or more users do not exist" ] })
      end
      Success()
    end

    def persist
      ActiveRecord::Base.transaction do
        @group = Group.create!(name: params[:name], description: params[:description], created_by: current_user)
        GroupsUser.create!(group: group, user: current_user)
        users_to_add&.each { |user| GroupsUser.find_or_create_by!(group: group, user: user) }
      end
      Success(group)
    rescue ActiveRecord::RecordInvalid => e
      Failure(errors: { base: [ e.message ] })
    end
  end
end

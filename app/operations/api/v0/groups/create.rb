module Api::V0::Groups
  class Create
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:name).filled(:string)
        optional(:description).maybe(:string)
      end
    end

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      yield persist

      Success(
        success: true,
        group: Api::V0::GroupSerializer.render_as_hash(group)
      )
    end

    private

    attr_reader :current_user, :params, :group

    def persist
      ActiveRecord::Base.transaction do
        @group = Group.create!(name: params[:name], description: params[:description], created_by: current_user)
        GroupsUser.create!(group: group, user: current_user)
      end
      Success(group)
    rescue ActiveRecord::RecordInvalid => e
      Failure(errors: { base: [ e.message ] })
    end
  end
end

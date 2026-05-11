module Api::V0::Groups
  class Update
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:id).filled(:integer)
        optional(:name).filled(:string)
        optional(:description).maybe(:string)
      end
    end

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      @group = current_user.groups.find_by(id: params[:id])
      return Failure(:not_found) unless group

      yield persist

      Success(
        success: true,
        group: Api::V0::GroupSerializer.render_as_hash(group)
      )
    end

    private

    attr_reader :params, :current_user, :group

    def persist
      group.update(params.slice(:name, :description).compact) ? Success(group) : Failure(errors: group.errors.to_hash)
    end
  end
end

module Api::V0::Groups
  class Destroy
    include Api::V0::ApplicationOperation

    def call(params, current_user:)
      @current_user = current_user
      @group        = current_user.groups.find_by(id: params[:id])

      return Failure(:not_found) unless group

      return Failure(errors: group.errors.to_hash) unless group.destroy

      Success(success: true)
    end

    private

    attr_reader :current_user, :group
  end
end

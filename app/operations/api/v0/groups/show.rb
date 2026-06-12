module Api::V0::Groups
  class Show
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:id).filled(:integer)
      end
    end

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      @group = current_user.groups.find_by(id: params[:id])
      return Failure(:not_found) unless group

      transactions = yield Transaction::Query.call(
        current_user: current_user,
        group_id:     group.id,
        per_page:     nil
      )
      formatted = yield Transaction::Formatter.call(transactions, current_user_id: current_user.id)

      Success(
        success: true,
        group: Api::V0::GroupSerializer.render_as_hash(group).merge(
          transactions: formatted
        )
      )
    end

    private

    attr_reader :params, :current_user, :group
  end
end

module Api::V0::Accounts
  class Show
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:id).filled(:integer)
      end
    end

    def call(params, current_user:)
      @current_user = current_user
      @account      = current_user.accounts.find_by(id: params[:id])

      return Failure(:not_found) unless account

      yield authorize?

      Success(
        success: true,
        account: Api::V0::AccountSerializer.render_as_hash(account)
      )
    end

    private

    attr_reader :current_user, :account

    def authorize?
      AccountPolicy.new(current_user, account).show? ? Success() : Failure(:forbidden)
    end
  end
end

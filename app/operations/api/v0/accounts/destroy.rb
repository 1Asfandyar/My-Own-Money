module Api::V0::Accounts
  class Destroy
    include Api::V0::ApplicationOperation

    def call(params, current_user:)
      @current_user = current_user
      @account      = current_user.accounts.find_by(id: params[:id])

      return Failure(:not_found) unless account

      yield authorize

      account.destroy

      Success(success: true)
    end

    private

    attr_reader :current_user, :account

    def authorize
      AccountPolicy.new(current_user, account).destroy? ? Success() : Failure(:forbidden)
    end
  end
end

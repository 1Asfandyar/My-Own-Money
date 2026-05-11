module Api::V0::Accounts
  class Update
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:id).filled(:integer)
        optional(:name).maybe(:string)
        optional(:current_balance_cents).maybe(:integer)
        optional(:initial_balance_cents).maybe(:integer)
        optional(:currency_id).maybe(:integer)
      end
    end

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      @account = current_user.accounts.find_by(id: params[:id])
      return Failure(:not_found) unless account

      yield authorize?
      yield persist

      Success(
        success: true,
        account: Api::V0::AccountSerializer.render_as_hash(account)
      )
    end

    private

    attr_reader :params, :current_user, :account

    def authorize?
      AccountPolicy.new(current_user, account).update? ? Success() : Failure(:forbidden)
    end

    def persist
      account.update(account_params) ? Success(account) : Failure(errors: account.errors.to_hash)
    end

    def account_params
      params.slice(:name, :current_balance_cents, :initial_balance_cents, :currency_id).compact
    end
  end
end

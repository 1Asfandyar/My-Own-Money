module Api::V0::Accounts
  class Create
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:name).filled(:string)
        optional(:current_balance_cents).maybe(:integer)
        optional(:initial_balance_cents).maybe(:integer)
        optional(:currency_id).maybe(:integer)
      end
    end

    def call(params, current_user:)
      @current_user = current_user
      validated    = yield validate_contract(account_params(params))
      @attributes  = validated.compact

      yield authorize
      yield persist

      Success(
        success: true,
        account: Api::V0::AccountSerializer.render_as_hash(account)
      )
    end

    private

    attr_reader :current_user, :attributes, :account

    def account_params(params)
      params.fetch(:account, params.fetch("account", {}))
    end

    def authorize
      AccountPolicy.new(current_user, Account.new).create? ? Success() : Failure(:forbidden)
    end

    def persist
      @account = Account.new(attributes.merge(user: current_user))
      account.save ? Success(account) : Failure(errors: account.errors.to_hash)
    end
  end
end

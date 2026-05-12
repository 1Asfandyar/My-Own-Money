module Api::V0::Transactions
  class Create
    include Api::V0::ApplicationOperation

    ALLOWED_TYPES = Transaction.transaction_types.keys.freeze

    class Contract < Api::V0::ApplicationContract
      params do
        required(:title).filled(:string)
        required(:transaction_type).filled(:string)
        required(:amount_cents).filled(:integer)
        required(:account_id).filled(:integer)
        required(:category_id).filled(:integer)
        optional(:transaction_date).maybe(:string)
        optional(:note).maybe(:string)
        optional(:currency_id).maybe(:integer)
      end

      rule(:transaction_type) do
        key.failure("must be one of #{ALLOWED_TYPES.join(', ')}") unless ALLOWED_TYPES.include?(value)
      end

      rule(:amount_cents) do
        key.failure("must be greater than 0") if value <= 0
      end

      rule(:transaction_date) do
        Time.parse(value)
      rescue ArgumentError, TypeError
        key.failure("must be a valid ISO 8601 datetime")
      end
    end

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      yield find_account
      yield find_category
      yield find_currency
      yield persist

      Success(
        success: true,
        transaction: Api::V0::TransactionSerializer.render_as_hash(transaction)
      )
    end

    private

    attr_reader :current_user, :params, :account, :category, :currency, :transaction

    def find_account
      @account = current_user.accounts.find_by(id: params[:account_id])
      @account ? Success() : Failure(:not_found)
    end

    def find_category
      @category = current_user.categories.find_by(id: params[:category_id])
      @category ? Success() : Failure(:not_found)
    end

    def find_currency
      return Success() unless params[:currency_id]
      @currency = Currency.find_by(id: params[:currency_id])
      @currency ? Success() : Failure(:not_found)
    end

    def persist
      result = Transaction::Personal::Create.call(
        user:             current_user,
        title:            params[:title],
        transaction_type: params[:transaction_type],
        amount_cents:     params[:amount_cents],
        account:          account,
        category:         category,
        transaction_date: Time.parse(params[:transaction_date]),
        note:             params[:note],
        currency:         currency
      )
      if result.success?
        @transaction = result.value!
        Success()
      else
        Failure(errors: result.failure[:errors])
      end
    end
  end
end

module Api::V0::Transactions
  class Index
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        optional(:account_id).maybe(:integer)
        optional(:category_id).maybe(:integer)
        optional(:friend_id).maybe(:integer)
        optional(:group_id).maybe(:integer)
        optional(:transaction_type).maybe(:string)
        optional(:visibility_type).maybe(:string)
        optional(:date_from).maybe(:string)
        optional(:date_to).maybe(:string)
        optional(:search).maybe(:string)
        optional(:page).maybe(:integer)
        optional(:per_page).maybe(:integer)
      end

      rule(:date_from) do
        next unless value
        Time.parse(value)
      rescue ArgumentError, TypeError
        key.failure("must be a valid ISO 8601 datetime")
      end

      rule(:date_to) do
        next unless value
        Time.parse(value)
      rescue ArgumentError, TypeError
        key.failure("must be a valid ISO 8601 datetime")
      end
    end

    def call(params, current_user:)
      @params       = params
      @current_user = current_user

      yield authorize?

      transactions = yield query_transactions
      formatted    = yield Transaction::Formatter.call(transactions, current_user_id: current_user.id)

      Success(success: true, transactions: formatted)
    end

    private

    attr_reader :current_user, :params

    def authorize?
      TransactionPolicy.new(current_user, Transaction).index? ? Success() : Failure(:forbidden)
    end

    def query_transactions
      Transaction::Query.call(
        current_user:     current_user,
        account_id:       params[:account_id],
        category_id:      params[:category_id],
        friend_id:        params[:friend_id],
        group_id:         params[:group_id],
        transaction_type: params[:transaction_type],
        visibility_type:  params[:visibility_type],
        date_from:        params[:date_from],
        date_to:          params[:date_to],
        search:           params[:search],
        page:             params[:page],
        per_page:         params[:per_page]
      )
    end
  end
end

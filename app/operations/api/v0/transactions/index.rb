module Api::V0::Transactions
  class Index
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        required(:type).value(included_in?: %w[shared personal none])
        optional(:account_id).maybe(:integer)
        optional(:category_id).maybe(:integer)
        optional(:date_from).maybe(:string)
        optional(:date_to).maybe(:string)
        optional(:search).maybe(:string)
      end

      rule(:account_id) do
        next unless values[:type] == "personal"
        key.failure("is required for type personal") if value.nil?
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

      Success(response_payload)
    end

    private

    attr_reader :current_user, :params

    def authorize?
      TransactionPolicy.new(current_user, Transaction).index? ? Success() : Failure(:forbidden)
    end

    def response_payload
      case params[:type]
      when "shared"
        Api::V0::Transactions::SharedTransactionsService.new(current_user, params).call
      when "personal"
        Api::V0::Transactions::PersonalTransactionsService.new(current_user, params).call
      else # 'none'
        transactions.each { |t| t.define_singleton_method(:split_amount_cents) { 0 } }
        {
          success: true,
          transactions: Api::V0::TransactionSerializer.render_as_hash(transactions)
        }
      end
    end

    def transactions
      @transactions ||= filtered_transactions
    end

    def filtered_transactions
      apply_filters(current_user.transactions.includes(:category)).order(transaction_date: :desc)
    end

    def apply_filters(scope)
      scope = scope.where(account_id: params[:account_id]) if params[:account_id]
      scope = scope.where(category_id: params[:category_id]) if params[:category_id]
      scope = scope.where("transaction_date >= ?", Time.parse(params[:date_from])) if params[:date_from]
      scope = scope.where("transaction_date <= ?", Time.parse(params[:date_to]))   if params[:date_to]
      if params[:search].present?
        term  = "%#{params[:search]}%"
        scope = scope.where("title ILIKE ? OR note ILIKE ?", term, term)
      end
      scope
    end
  end
end

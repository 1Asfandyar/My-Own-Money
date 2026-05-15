module Api::V0::Transactions
  class Index
    include Api::V0::ApplicationOperation

    class Contract < Api::V0::ApplicationContract
      params do
        optional(:account_id).maybe(:integer)
        optional(:category_id).maybe(:integer)
        optional(:date_from).maybe(:string)
        optional(:date_to).maybe(:string)
        optional(:search).maybe(:string)
        optional(:by_category).maybe(:bool)
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
      return transactions_by_category_payload if params[:by_category]

      {
        success: true,
        transactions: Api::V0::TransactionSerializer.render_as_hash(transactions)
      }
    end

    def transactions
      @transactions ||= filtered_transactions
    end

    def transactions_by_category_payload
      {
        success: true,
        total_amount_cents: total_amount_cents,
        total_absolute_amount_cents: total_absolute_amount_cents,
        total_account_balance_cents: total_account_balance_cents,
        total_spent_cents: total_spent_cents,
        total_income_cents: total_income_cents,
        categories: category_summaries
      }
    end

    def category_summaries
      category_transactions.group_by(&:category).map do |category, transactions|
        amount_cents = signed_total_for(transactions)

        {
          category: Api::V0::CategorySerializer.render_as_hash(category),
          amount_cents: amount_cents,
          percentage: percentage_for(amount_cents),
          transactions: Api::V0::TransactionSerializer.render_as_hash(transactions)
        }
      end
    end

    def category_transactions
      @category_transactions ||= transactions.select do |transaction|
        transaction.category_id.present? && (transaction.expense? || transaction.income?)
      end
    end

    def total_amount_cents
      @total_amount_cents ||= signed_total_for(category_transactions)
    end

    def total_absolute_amount_cents
      @total_absolute_amount_cents ||= category_transactions.sum do |transaction|
        transaction.amount_cents.abs
      end
    end

    def total_spent_cents
      @total_spent_cents ||= category_transactions.sum do |transaction|
        transaction.category.expense? ? transaction.amount_cents.abs : 0
      end
    end

    def total_income_cents
      @total_income_cents ||= category_transactions.sum do |transaction|
        transaction.category.income? ? transaction.amount_cents.abs : 0
      end
    end

    def total_account_balance_cents
      @total_account_balance_cents ||= accounts_for_percentage.sum(&:current_balance_cents)
    end

    def accounts_for_percentage
      @accounts_for_percentage ||= begin
        if params[:account_id]
          current_user.accounts.where(id: params[:account_id]).to_a
        else
          current_user.accounts.to_a
        end
      end
    end

    def signed_total_for(transactions)
      transactions.sum do |transaction|
        transaction.category.income? ? transaction.amount_cents : -transaction.amount_cents
      end
    end

    def percentage_for(amount_cents)
      denominator = total_account_balance_cents.abs
      return 0.0 if denominator.zero?

      ((amount_cents.abs.to_f / denominator) * 100).round(2)
    end

    def filtered_transactions
      scope = current_user.transactions.includes(:category).order(transaction_date: :desc)
      scope = scope.where(account_id: params[:account_id])   if params[:account_id]
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

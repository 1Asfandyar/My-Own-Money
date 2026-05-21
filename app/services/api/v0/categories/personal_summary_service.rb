module Api::V0::Categories
  class PersonalSummaryService
    def initialize(current_user, params)
      @current_user = current_user
      @params = params
    end

    def call
      {
        success: true,
        categories: category_summaries
      }
    end

    private

    attr_reader :current_user, :params

    def category_summaries
      categorized_transactions.group_by { |item| item[:category] }.map do |category, items|
        amount_cents = items.sum { |item| item[:signed_amount] }
        balance_cents = items.sum { |item| item[:transaction].amount_cents }
        transactions = items.map { |item| item[:transaction] }
        transactions.each { |t| t.define_singleton_method(:split_amount_cents) { 0 } }

        {
          category: serialized_category(category, balance_cents),
          amount_cents: amount_cents,
          percentage: percentage_for(amount_cents),
          transactions: Api::V0::TransactionSerializer.render_as_hash(transactions, view: :with_categories)
        }
      end
    end

    def serialized_category(category, balance_cents)
      category_hash = Api::V0::CategorySerializer.render_as_hash(category)
      key = category_hash.key?(:balance_cents) ? :balance_cents : "balance_cents"
      category_hash[key] = balance_cents
      category_hash
    end

    def categorized_transactions
      @categorized_transactions ||= category_transactions.map do |transaction|
        is_income = transaction.category.category_type == "income"
        signed_amount = is_income ? transaction.amount_cents : -transaction.amount_cents
        {
          transaction: transaction,
          category: transaction.category,
          signed_amount: signed_amount,
          is_expense: !is_income
        }
      end
    end

    def category_transactions
      @category_transactions ||= filtered_transactions
        .where.not(category_id: nil)
        .where(transaction_type: [ :expense, :income ])
    end

    def filtered_transactions
      apply_filters(current_user.transactions.includes(:category)).order(transaction_date: :desc)
    end

    def account_balance_cents
      @account_balance_cents ||= current_user.accounts.find(params[:account_id]).current_balance_cents
    end

    def percentage_for(amount_cents)
      denominator = account_balance_cents.abs
      return 0.0 if denominator.zero?

      ((amount_cents.abs.to_f / denominator) * 100).round(2)
    end

    def apply_filters(scope)
      scope = scope.where(account_id: params[:account_id])
      scope = scope.where(category_id: params[:category_id]) if params[:category_id]
      scope
    end
  end
end

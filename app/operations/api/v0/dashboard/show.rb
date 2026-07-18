module Api::V0::Dashboard
  class Show
    include Api::V0::ApplicationOperation

    def call(_params = {}, current_user:)
      @current_user = current_user

      yield authorize?

      accounts = yield accounts_data
      categories = yield categories_data
      friendships = yield friendships_data

      Success(
        success: true,
        summary: summary_data,
        accounts: accounts,
        categories: categories,
        friendships: friendships
      )
    end

    private

    attr_reader :current_user

    def authorize?
      current_user.present? ? Success() : Failure(:forbidden)
    end

    def month_key
      @month_key ||= Date.current.strftime("%Y-%m")
    end

    def monthly_overview
      @monthly_overview ||= Reports::MonthlySummary.call(current_user, month_key).fetch(:overview)
    end

    def summary_data
      {
        total_income: monthly_overview[:total_income_cents],
        total_expense: monthly_overview[:total_expenses_cents],
        total_owed_to_you_cents: Debt.where(to_user_id: current_user.id).sum(:amount_cents),
        total_you_owe_cents: Debt.where(from_user_id: current_user.id).sum(:amount_cents)
      }
    end

    def accounts_data
      result = Api::V0::Accounts::Index.call({}, current_user: current_user)
      return Failure(result.failure) if result.failure?

      Success(result.value![:accounts])
    end

    def categories_data
      result = Api::V0::Categories::Index.call({ include_zero_balance: true }, current_user: current_user)
      return Failure(result.failure) if result.failure?

      Success(result.value![:categories])
    end

    def friendships_data
      result = Api::V0::Friendships::Index.call({}, current_user: current_user)
      return Failure(result.failure) if result.failure?

      Success(result.value![:friendships])
    end
  end
end

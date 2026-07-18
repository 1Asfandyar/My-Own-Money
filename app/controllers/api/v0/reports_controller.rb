module Api::V0
  class ReportsController < ApiController
    resource_description do
      short "Financial reports"
      description "Monthly financial summary reports for the current user. All endpoints require JWT authentication."
      api_version "v0"
    end

    api :GET, "/v0/reports/summary", "Get monthly financial summary"
    description <<~DESC
      Returns a financial summary for the given month (defaults to the current month).
      Includes income/expense overview, account balances, spending by category,
      live shared-money debt balances, live net worth, and a 3-month income/expense trend.

      **TypeScript Types**

      ```typescript
      // Input (all optional query params)
      type Query = {
        month?: string;  // YYYY-MM format; defaults to current month
      };

      // Output
      type Response = {
        success: boolean;
        report: Report;
      };

      type Report = {
        period:               string;           // e.g. "June 2026"
        overview:             Overview;
        accounts:             Account[];
        total_balance_cents:  number;
        spending_by_category: CategorySpend[];
        shared_money:         SharedMoney;
        net_worth:            NetWorth;
        trend:                TrendMonth[];
      };

      type Overview = {
        total_income_cents:   number;
        total_expenses_cents: number;
        net_cents:            number;
        savings_rate_percent: number;
      };

      type Account = {
        id:            number;
        name:          string;
        balance_cents: number;
        currency_symbol: string | null;
      };

      type CategorySpend = {
        category_id:         number;
        category_name:       string;
        amount_cents:        number;
        percent_of_expenses: number;
        transaction_count:   number;
      };

      type SharedMoney = {
        you_will_receive_cents: number;
        you_owe_cents:          number;
        net_cents:              number;
        breakdown: Array<{
          user_id:      number;
          name:         string;
          direction:    "owes_you" | "you_owe";
          amount_cents: number;
        }>;
      };

      type NetWorth = {
        total_accounts_balance_cents: number;
        total_owed_to_you_cents:      number;
        total_you_owe_cents:          number;
        net_worth_cents:              number;
      };

      type TrendMonth = {
        month:          string;   // e.g. "April 2026"
        month_key:      string;   // e.g. "2026-04"
        income_cents:   number;
        expenses_cents: number;
      };
      ```
    DESC
    param :month, String, required: false, desc: "Month to summarise in YYYY-MM format (defaults to current month)"
    error code: 401, desc: "Unauthorized — missing or invalid JWT"
    error code: 403, desc: "Forbidden — not authenticated"
    error code: 422, desc: "Invalid month format — must be YYYY-MM"
    returns code: 200, desc: "Success" do
      param :success, :bool, desc: "Operation status"
      param :report, Hash, desc: "Monthly financial report" do
        param :period, String, desc: "Human-readable month label (e.g. 'June 2026')"
        param :overview, Hash, desc: "Income/expense totals for the period" do
          param :total_income_cents,   Integer, desc: "Sum of all income transactions in cents"
          param :total_expenses_cents, Integer, desc: "Sum of all personal + shared expenses in cents"
          param :net_cents,            Integer, desc: "Income minus expenses in cents"
          param :savings_rate_percent, Integer, desc: "Net as a percentage of income (clamped to -999..100); 0 when income is zero"
        end
        param :accounts, Array, desc: "Non-archived accounts with current balances" do
          param :id,            Integer, desc: "Account ID"
          param :name,          String,  desc: "Account name"
          param :balance_cents, Integer, desc: "Current balance in cents"
          param :currency_symbol, String,  desc: "Currency symbol (e.g. $)"
        end
        param :total_balance_cents, Integer, desc: "Sum of all non-archived account balances in cents"
        param :spending_by_category, Array, desc: "Expense breakdown per category, sorted by amount descending" do
          param :category_id,         Integer, desc: "Category ID"
          param :category_name,       String,  desc: "Category name"
          param :amount_cents,        Integer, desc: "Total spent in this category in cents"
          param :percent_of_expenses, Integer, desc: "Percentage of total expenses"
          param :transaction_count,   Integer, desc: "Number of transactions in this category"
        end
        param :shared_money, Hash, desc: "Live debt balances (not period-bound)" do
          param :you_will_receive_cents, Integer, desc: "Total owed to the current user across all friends"
          param :you_owe_cents,          Integer, desc: "Total the current user owes across all friends"
          param :net_cents,              Integer, desc: "you_will_receive_cents minus you_owe_cents"
          param :breakdown, Array, desc: "Per-person debt detail" do
            param :user_id,      Integer, desc: "Other user's ID"
            param :name,         String,  desc: "Other user's display name"
            param :direction,    String,  desc: "'owes_you' or 'you_owe'"
            param :amount_cents, Integer, desc: "Amount in cents"
          end
        end
        param :net_worth, Hash, desc: "Live net worth totals (not period-bound)" do
          param :total_accounts_balance_cents, Integer, desc: "Sum of all non-archived account balances in cents"
          param :total_owed_to_you_cents,      Integer, desc: "Total owed to the current user across all friends, in cents"
          param :total_you_owe_cents,          Integer, desc: "Total the current user owes across all friends, in cents"
          param :net_worth_cents,              Integer, desc: "Accounts balance plus money owed to you minus money you owe, in cents"
        end
        param :trend, Array, desc: "Income and expenses for the current month and the two preceding months" do
          param :month,          String,  desc: "Human-readable month label (e.g. 'April 2026')"
          param :month_key,      String,  desc: "YYYY-MM key (e.g. '2026-04')"
          param :income_cents,   Integer, desc: "Total income in cents for the month"
          param :expenses_cents, Integer, desc: "Total expenses in cents for the month"
        end
      end
    end
    def summary
      Api::V0::Reports::Summary.call(params.to_unsafe_h, current_user: current_user) do |result|
        result.success { |data| render json: data, status: :ok }
        result.failure(:forbidden) { forbidden_response }
        result.failure { |errors| unprocessable_entity(errors) }
      end
    end
  end
end

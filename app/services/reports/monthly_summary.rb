module Reports
  class MonthlySummary < ApplicationService
    def call(current_user, month_param = nil)
      @current_user = current_user
      @month = parse_month(month_param)

      monthly_report
    end

    private

    attr_reader :current_user, :month

    def monthly_report
      {
        period:               period_label,
        overview:             overview,
        accounts:             accounts_data,
        total_balance_cents:  total_balance_cents,
        spending_by_category: spending_by_category,
        shared_money:         shared_money,
        net_worth:            net_worth,
        trend:                trend
      }
    end

    def parse_month(param)
      return Date.current.beginning_of_month if param.blank?

      Date.strptime(param, "%Y-%m").beginning_of_month
    end

    def month_range
      month.beginning_of_month...month.next_month.beginning_of_month
    end

    def period_label
      month.strftime("%B %Y")
    end

    # ---------------------------------------------------------------------------
    # Overview
    # ---------------------------------------------------------------------------

    def total_income_cents
      @total_income_cents ||= Transaction
        .where(user_id: current_user.id, transaction_type: :income)
        .where(transaction_date: month_range)
        .sum(:amount_cents)
    end

    def personal_expenses_cents
      @personal_expenses_cents ||= Transaction
        .where(user_id: current_user.id, transaction_type: :expense, visibility_type: :personal)
        .where(transaction_date: month_range)
        .sum(:amount_cents)
    end

    def shared_expenses_cents
      @shared_expenses_cents ||= TransactionSplit
        .joins(:financial_transaction)
        .where(user_id: current_user.id)
        .merge(Transaction.expense)
        .where(transactions: { transaction_date: month_range })
        .sum(:owed_amount_cents)
    end

    def total_expenses_cents
      @total_expenses_cents ||= personal_expenses_cents + shared_expenses_cents
    end

    def net_cents
      total_income_cents - total_expenses_cents
    end

    def savings_rate_percent
      return 0 if total_income_cents.zero?

      ((net_cents.to_f / total_income_cents) * 100).round.clamp(-999, 100)
    end

    def overview
      {
        total_income_cents:   total_income_cents,
        total_expenses_cents: total_expenses_cents,
        net_cents:            net_cents,
        savings_rate_percent: savings_rate_percent
      }
    end

    # ---------------------------------------------------------------------------
    # Accounts
    # ---------------------------------------------------------------------------

    def active_accounts
      @active_accounts ||= current_user.accounts.where(is_archived: false)
    end

    def accounts_data
      active_accounts.map do |account|
        {
          id:            account.id,
          name:          account.name,
          balance_cents: account.current_balance_cents,
          currency_code: current_user.currency&.code
        }
      end
    end

    def total_balance_cents
      active_accounts.sum(:current_balance_cents)
    end

    # ---------------------------------------------------------------------------
    # Spending by category
    # ---------------------------------------------------------------------------

    def spending_by_category
      personal_amounts = Transaction
        .where(user_id: current_user.id, transaction_type: :expense, visibility_type: :personal)
        .where(transaction_date: month_range)
        .where.not(category_id: nil)
        .group(:category_id)
        .sum(:amount_cents)

      personal_counts = Transaction
        .where(user_id: current_user.id, transaction_type: :expense, visibility_type: :personal)
        .where(transaction_date: month_range)
        .where.not(category_id: nil)
        .group(:category_id)
        .count

      shared_base = TransactionSplit
        .joins(:financial_transaction)
        .where(user_id: current_user.id)
        .merge(Transaction.expense)
        .where(transactions: { transaction_date: month_range })
        .where.not(transactions: { category_id: nil })

      shared_amounts = shared_base.group("transactions.category_id").sum(:owed_amount_cents)
      shared_counts  = shared_base.group("transactions.category_id").count

      amounts = personal_amounts.merge(shared_amounts) { |_, p, s| p + s }
      counts  = personal_counts.merge(shared_counts)   { |_, p, s| p + s }

      return [] if amounts.empty?

      categories = Category.where(id: amounts.keys).index_by(&:id)

      amounts.filter_map do |category_id, amount|
        cat = categories[category_id]
        next unless cat

        percent = total_expenses_cents.zero? ? 0 : ((amount.to_f / total_expenses_cents) * 100).round

        {
          category_id:          category_id,
          category_name:        cat.name,
          amount_cents:         amount,
          percent_of_expenses:  percent,
          transaction_count:    counts.fetch(category_id, 0)
        }
      end.sort_by { |c| -c[:amount_cents] }
    end

    # ---------------------------------------------------------------------------
    # Shared money (live debt balances — not period-bound)
    # ---------------------------------------------------------------------------

    def shared_money
      @shared_money ||= begin
        receive_debts = Debt.where(to_user_id: current_user.id).includes(:from_user)
        owe_debts     = Debt.where(from_user_id: current_user.id).includes(:to_user)

        you_will_receive = receive_debts.sum(:amount_cents)
        you_owe          = owe_debts.sum(:amount_cents)

        breakdown = []

        receive_debts.each do |debt|
          breakdown << {
            user_id:      debt.from_user_id,
            name:         debt.from_user.full_name,
            direction:    "owes_you",
            amount_cents: debt.amount_cents
          }
        end

        owe_debts.each do |debt|
          breakdown << {
            user_id:      debt.to_user_id,
            name:         debt.to_user.full_name,
            direction:    "you_owe",
            amount_cents: debt.amount_cents
          }
        end

        {
          you_will_receive_cents: you_will_receive,
          you_owe_cents:          you_owe,
          net_cents:              you_will_receive - you_owe,
          breakdown:              breakdown
        }
      end
    end

    # ---------------------------------------------------------------------------
    # Net worth (live totals — not period-bound)
    # ---------------------------------------------------------------------------

    def net_worth
      {
        total_accounts_balance_cents: total_balance_cents,
        total_owed_to_you_cents:      shared_money[:you_will_receive_cents],
        total_you_owe_cents:          shared_money[:you_owe_cents],
        net_worth_cents:              total_balance_cents + shared_money[:you_will_receive_cents] - shared_money[:you_owe_cents]
      }
    end

    # ---------------------------------------------------------------------------
    # Trend (current month + 2 preceding months)
    # ---------------------------------------------------------------------------

    def trend
      [ 2, 1, 0 ].map { |offset| trend_month_data(month - offset.months) }
    end

    def trend_month_data(target_month)
      range = target_month.beginning_of_month...target_month.next_month.beginning_of_month

      income = Transaction
        .where(user_id: current_user.id, transaction_type: :income)
        .where(transaction_date: range)
        .sum(:amount_cents)

      p_exp = Transaction
        .where(user_id: current_user.id, transaction_type: :expense, visibility_type: :personal)
        .where(transaction_date: range)
        .sum(:amount_cents)

      s_exp = TransactionSplit
        .joins(:financial_transaction)
        .where(user_id: current_user.id)
        .merge(Transaction.expense)
        .where(transactions: { transaction_date: range })
        .sum(:owed_amount_cents)

      {
        month:          target_month.strftime("%B %Y"),
        month_key:      target_month.strftime("%Y-%m"),
        income_cents:   income,
        expenses_cents: p_exp + s_exp
      }
    end
  end
end

class MonthlyReportJob < ApplicationJob
  queue_as :default

  # Enqueue: MonthlyReportJob.perform_later(user_id: user.id, month: "2026-05")
  def perform(user_id:, month:)
    user = User.find(user_id)
    date = Date.parse("#{month}-01")

    transactions = Transaction.where(
      user: user,
      date: date.beginning_of_month..date.end_of_month
    )

    total_income  = transactions.where(transaction_type: "income").sum(:amount)
    total_expense = transactions.where(transaction_type: "expense").sum(:amount)
    net           = total_income - total_expense

    Rails.logger.info(
      "[MonthlyReportJob] user=#{user_id} month=#{month} " \
      "income=#{total_income} expenses=#{total_expense} net=#{net}"
    )
  end
end

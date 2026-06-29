# frozen_string_literal: true

class Transaction::Settlement::Create < ApplicationService
  include Transaction::Helpers

  # paid_by_user: User who is paying (the debtor)
  # paid_to_user: User being paid (the creditor)
  def call(paid_by_user:, paid_to_user:, title:, amount_cents:, paid_by_account:,
           paid_to_account:, transaction_date:, note: nil, currency: nil)
    @paid_by_user     = paid_by_user
    @paid_to_user     = paid_to_user
    @title            = title
    @amount_cents     = amount_cents
    @paid_by_account  = paid_by_account
    @paid_to_account  = paid_to_account
    @transaction_date = transaction_date
    @note             = note
    @currency         = currency
    persist
  end

  private

  attr_reader :paid_by_user, :paid_to_user, :title, :amount_cents, :paid_by_account,
              :paid_to_account, :transaction_date, :note, :currency, :transaction

  def persist
    debt_result = nil

    ActiveRecord::Base.transaction do
      @transaction = Transaction.create!(
        user:             paid_by_user,
        settles_user:     paid_to_user,
        transaction_type: :settlement,
        visibility_type:  :shared,
        title:            title,
        amount_cents:     amount_cents,
        account:          paid_by_account,
        transfer_account: paid_to_account,
        transaction_date: transaction_date,
        note:             note,
        currency:         currency || paid_by_account.currency
      )

      # paid_by_user is paying out → balance decreases
      update_account_balance(account: paid_by_account, transaction_type: :expense, amount_cents: amount_cents)

      # paid_to_user is receiving → balance increases
      update_account_balance(account: paid_to_account, transaction_type: :income, amount_cents: amount_cents)

      # Reduce the debt: paid_by_user owes paid_to_user some amount.
      debt_result = Debts::UpdateBalance.call(
        debtor_user:  paid_to_user,
        payer_user:   paid_by_user,
        amount_cents: amount_cents
      )

      raise ActiveRecord::Rollback if debt_result.failure?
    end

    return debt_result if debt_result&.failure?

    Success(transaction)
  rescue ActiveRecord::RecordInvalid => e
    Failure(errors: e.record.errors.to_hash)
  end
end

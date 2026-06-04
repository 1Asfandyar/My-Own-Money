# frozen_string_literal: true

class Transaction::Settlement::Create < ApplicationService
  include Transaction::Helpers

  # settler:      User who is paying (the debtor)
  # settles_user: User being paid (the creditor)
  def call(settler:, settles_user:, title:, amount_cents:, account:, transaction_date:,
           note: nil, currency: nil)
    @settler          = settler
    @settles_user     = settles_user
    @title            = title
    @amount_cents     = amount_cents
    @account          = account
    @transaction_date = transaction_date
    @note             = note
    @currency         = currency
    persist
  end

  private

  attr_reader :settler, :settles_user, :title, :amount_cents, :account,
              :transaction_date, :note, :currency, :transaction

  def persist
    debt_result = nil

    ActiveRecord::Base.transaction do
      @transaction = Transaction.create!(
        user:             settler,
        settles_user:     settles_user,
        transaction_type: :settlement,
        visibility_type:  :shared,
        title:            title,
        amount_cents:     amount_cents,
        account:          settler_default_account,
        transaction_date: transaction_date,
        note:             note,
        currency:         currency || account.currency
      )

      # for Payer (settler), settlement is an expense → balance decreases
      # reduce the balance of payer's account by the settlement amount
      # for now there is no category for settlement
      update_account_balance(account: settler_default_account, transaction_type: :expense, amount_cents: amount_cents)

      # for Debtor (settles_user), settlement is an income → balance increases
      update_account_balance(account: settles_user.default_account, transaction_type: :income, amount_cents: amount_cents)

      # Reduce the debt: settler owes settles_user some amount.
      # Calling with debtor=settles_user and payer=settler triggers adjust_reverse_debt
      # which subtracts amount_cents from the existing settler→settles_user debt.
      debt_result = Debts::UpdateBalance.call(
        debtor_user:  settles_user,
        payer_user:   settler,
        amount_cents: amount_cents
      )

      raise ActiveRecord::Rollback if debt_result.failure?
    end

    return debt_result if debt_result&.failure?

    Success(transaction)
  rescue ActiveRecord::RecordInvalid => e
    Failure(errors: e.record.errors.to_hash)
  end

  def settler_default_account
    @settler_default_account ||= @account || settler.default_account
  end
end

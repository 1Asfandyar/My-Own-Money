# frozen_string_literal: true

class Transaction::Transfer::Create < ApplicationService
  include Transaction::Helpers

  def call(user:, title:, amount_cents:, from_account:, to_account:, transaction_date:, note: nil)
    @user             = user
    @title            = title
    @amount_cents     = amount_cents
    @from_account     = from_account
    @to_account       = to_account
    @transaction_date = transaction_date
    @note             = note
    persist
  end

  private

  attr_reader :user, :title, :amount_cents, :from_account, :to_account,
              :transaction_date, :note, :transaction

  def persist
    ActiveRecord::Base.transaction do
      @transaction = Transaction.create!(transaction_params)
      update_transfer_balance(from_account: from_account, to_account: to_account, amount_cents: amount_cents)
    end
    Success(transaction)
  rescue ActiveRecord::RecordInvalid => e
    Failure(errors: e.record.errors.to_hash)
  end

  def transaction_params
    {
      user:             user,
      transaction_type: :transfer,
      visibility_type:  :personal,
      title:            title,
      amount_cents:     amount_cents,
      account:          from_account,
      transfer_account: to_account,
      transaction_date: transaction_date,
      note:             note
    }.compact
  end
end

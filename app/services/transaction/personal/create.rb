# frozen_string_literal: true

class Transaction::Personal::Create < ApplicationService
  include Transaction::Helpers

  def call(user:, transaction_type:, title:, amount_cents:, account:, transaction_date:, note: nil, category: nil, currency: nil)
    @user             = user
    @transaction_type = transaction_type
    @title            = title
    @amount_cents     = amount_cents
    @account          = account
    @transaction_date = transaction_date
    @note             = note
    @category         = category
    @currency         = currency
    persist
  end

  private
  attr_reader :user, :transaction_type, :title, :amount_cents, :account, :transaction_date, :note, :category, :currency, :transaction

  def persist
    ActiveRecord::Base.transaction do
      @transaction = Transaction.create!(transaction_params)
      update_account_balance(account: account, transaction_type: transaction_type, amount_cents: amount_cents)
    end
    Success(transaction)
  rescue ActiveRecord::RecordInvalid => e
    Failure(errors: e.record.errors.to_hash)
  end

  def transaction_params
    {
      user:             user,
      transaction_type: transaction_type,
      visibility_type:  :personal,
      title:            title,
      amount_cents:     amount_cents,
      account:          account,
      transaction_date: transaction_date,
      note:             note,
      category:         category,
      currency:         currency || account.currency
    }.compact
  end

  # def update_account_balance(account: account, transaction_type: transaction_type, amount_cents: amount_cents)
  #   if transaction_type == :income || transaction_type == "income"
  #     account.current_balance_cents += amount_cents
  #   elsif transaction_type == :expense || transaction_type == "expense"
  #     account.current_balance_cents -= amount_cents
  #   end
  #   account.save!
  # end
end

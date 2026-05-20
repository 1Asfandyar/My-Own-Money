# frozen_string_literal: true

class Transaction::Personal::Update < ApplicationService
  include Transaction::Helpers

  def call(transaction:, **attrs)
    @transaction = transaction
    @attrs       = attrs
    persist
  end

  private

  attr_reader :transaction, :attrs

  def persist
    old_account      = transaction.account
    old_type         = transaction.transaction_type
    old_amount_cents = transaction.amount_cents
    old_category     = transaction.category

    new_account      = attrs[:account]          || old_account
    new_type         = attrs[:transaction_type] || old_type
    new_amount_cents = attrs[:amount_cents]     || old_amount_cents
    new_category     = attrs[:category]         || old_category

    ActiveRecord::Base.transaction do
      revert_account_balance(account: old_account, transaction_type: old_type, amount_cents: old_amount_cents)
      revert_category_balance(category: old_category, amount_cents: old_amount_cents)
      transaction.update!(update_params)
      update_account_balance(account: new_account.reload, transaction_type: new_type, amount_cents: new_amount_cents)
      update_category_balance(category: new_category, amount_cents: new_amount_cents)
    end

    Success(transaction)
  rescue ActiveRecord::RecordInvalid => e
    Failure(errors: e.record.errors.to_hash)
  end

  def update_params
    {
      title:            attrs[:title],
      transaction_type: attrs[:transaction_type],
      amount_cents:     attrs[:amount_cents],
      account:          attrs[:account],
      category:         attrs[:category],
      transaction_date: attrs[:transaction_date],
      note:             attrs[:note],
      currency:         attrs[:currency]
    }.compact
  end
end

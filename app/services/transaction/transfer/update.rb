# frozen_string_literal: true

class Transaction::Transfer::Update < ApplicationService
  include Transaction::Helpers

  def call(transaction:, **attrs)
    @transaction = transaction
    @attrs       = attrs
    persist
  end

  private

  attr_reader :transaction, :attrs

  def persist
    old_type         = transaction.transaction_type
    old_amount_cents = transaction.amount_cents

    new_from_account = attrs[:from_account]     || transaction.account
    new_to_account   = attrs[:to_account]       || transaction.transfer_account
    new_amount_cents = attrs[:amount_cents]     || old_amount_cents
    new_type         = attrs[:transaction_type] || old_type

    ActiveRecord::Base.transaction do
      revert_old_balance(old_type, old_amount_cents)
      transaction.update!(update_params)
      apply_new_balance(new_type, new_from_account, new_to_account, new_amount_cents)
    end

    Success(transaction)
  rescue ActiveRecord::RecordInvalid => e
    Failure(errors: e.record.errors.to_hash)
  end

  def revert_old_balance(old_type, old_amount_cents)
    if old_type.to_sym == :transfer
      revert_transfer_balance(
        from_account: transaction.account,
        to_account:   transaction.transfer_account,
        amount_cents: old_amount_cents
      )
    else
      revert_account_balance(
        account:          transaction.account,
        transaction_type: old_type,
        amount_cents:     old_amount_cents
      )
    end
  end

  def apply_new_balance(new_type, new_from_account, new_to_account, new_amount_cents)
    if new_type.to_sym == :transfer
      update_transfer_balance(
        from_account: new_from_account.reload,
        to_account:   new_to_account.reload,
        amount_cents: new_amount_cents
      )
    else
      update_account_balance(
        account:          new_from_account.reload,
        transaction_type: new_type,
        amount_cents:     new_amount_cents
      )
    end
  end

  def update_params
    {
      title:            attrs[:title],
      amount_cents:     attrs[:amount_cents],
      account:          attrs[:from_account],
      transfer_account: attrs[:to_account],
      transaction_type: attrs[:transaction_type],
      transaction_date: attrs[:transaction_date],
      note:             attrs[:note]
    }.compact
  end
end

# frozen_string_literal: true

class Transaction::Settlement::Update < ApplicationService
  include Transaction::Helpers

  def call(transaction:, **attrs)
    @transaction = transaction
    @attrs       = attrs
    persist
  end

  private

  attr_reader :transaction, :attrs

  def persist
    old_paid_by_account = transaction.account
    old_paid_to_account = transaction.transfer_account || transaction.settles_user.preferred_account
    old_amount_cents    = transaction.amount_cents
    paid_by_user        = transaction.user
    paid_to_user        = transaction.settles_user

    new_paid_by_account = attrs[:paid_by_account] || old_paid_by_account
    new_paid_to_account = attrs[:paid_to_account] || old_paid_to_account
    new_amount_cents    = attrs[:amount_cents]     || old_amount_cents

    debt_result = nil

    ActiveRecord::Base.transaction do
      # Revert old balance changes
      revert_account_balance(account: old_paid_by_account, transaction_type: :expense, amount_cents: old_amount_cents)
      revert_account_balance(account: old_paid_to_account, transaction_type: :income,  amount_cents: old_amount_cents)

      # Restore the debt that was reduced when the settlement was created
      debt_result = Debts::UpdateBalance.call(
        debtor_user:  paid_by_user,
        payer_user:   paid_to_user,
        amount_cents: old_amount_cents
      )
      raise ActiveRecord::Rollback if debt_result.failure?

      transaction.update!(update_params(new_paid_by_account, new_paid_to_account, new_amount_cents))

      # Apply new balance changes
      update_account_balance(account: new_paid_by_account.reload, transaction_type: :expense, amount_cents: new_amount_cents)
      update_account_balance(account: new_paid_to_account.reload, transaction_type: :income,  amount_cents: new_amount_cents)

      # Reduce the debt again with the new amount
      debt_result = Debts::UpdateBalance.call(
        debtor_user:  paid_to_user,
        payer_user:   paid_by_user,
        amount_cents: new_amount_cents
      )
      raise ActiveRecord::Rollback if debt_result.failure?
    end

    return debt_result if debt_result&.failure?

    Success(transaction.reload)
  rescue ActiveRecord::RecordInvalid => e
    Failure(errors: e.record.errors.to_hash)
  end

  def update_params(new_paid_by_account, new_paid_to_account, new_amount_cents)
    {
      title:            attrs[:title],
      amount_cents:     new_amount_cents,
      account:          new_paid_by_account,
      transfer_account: new_paid_to_account,
      transaction_date: attrs[:transaction_date],
      note:             attrs[:note],
      currency:         attrs[:currency]
    }.compact
  end
end

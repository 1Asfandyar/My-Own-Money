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
    old_account      = transaction.account
    old_amount_cents = transaction.amount_cents
    settles_user     = transaction.settles_user
    settler          = transaction.user

    new_account      = attrs[:account]      || old_account
    new_amount_cents = attrs[:amount_cents] || old_amount_cents

    debt_result = nil

    ActiveRecord::Base.transaction do
      # Revert old balance changes (mirrors Settlement::Destroy)
      revert_account_balance(account: old_account, transaction_type: :expense, amount_cents: old_amount_cents)
      revert_account_balance(account: settles_user.default_account, transaction_type: :income, amount_cents: old_amount_cents)

      # Restore the debt that was reduced when the settlement was created
      debt_result = Debts::UpdateBalance.call(
        debtor_user:  settler,
        payer_user:   settles_user,
        amount_cents: old_amount_cents
      )
      raise ActiveRecord::Rollback if debt_result.failure?

      transaction.update!(update_params(new_account, new_amount_cents))

      # Apply new balance changes (mirrors Settlement::Create)
      update_account_balance(account: new_account.reload, transaction_type: :expense, amount_cents: new_amount_cents)
      update_account_balance(account: settles_user.default_account.reload, transaction_type: :income, amount_cents: new_amount_cents)

      # Reduce the debt again with the new amount
      debt_result = Debts::UpdateBalance.call(
        debtor_user:  settles_user,
        payer_user:   settler,
        amount_cents: new_amount_cents
      )
      raise ActiveRecord::Rollback if debt_result.failure?
    end

    return debt_result if debt_result&.failure?

    Success(transaction.reload)
  rescue ActiveRecord::RecordInvalid => e
    Failure(errors: e.record.errors.to_hash)
  end

  def update_params(new_account, new_amount_cents)
    {
      title:            attrs[:title],
      amount_cents:     new_amount_cents,
      account:          new_account,
      transaction_date: attrs[:transaction_date],
      note:             attrs[:note],
      currency:         attrs[:currency]
    }.compact
  end
end

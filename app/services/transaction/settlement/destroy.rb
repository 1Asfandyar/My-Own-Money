# frozen_string_literal: true

class Transaction::Settlement::Destroy < ApplicationService
  include Transaction::Helpers

  def call(transaction:)
    @transaction = transaction
    reverse
  end

  private

  attr_reader :transaction

  def reverse
    ActiveRecord::Base.transaction do
      # Revert settler's account balance (settlement was recorded as expense for settler)
      revert_account_balance(
        account:          transaction.account,
        transaction_type: :expense,
        amount_cents:     transaction.amount_cents
      )

      # Revert settles_user's account balance (settlement was recorded as income for settles_user)
      revert_account_balance(
        account:          transaction.settles_user.default_account,
        transaction_type: :income,
        amount_cents:     transaction.amount_cents
      )

      # Restore the debt that was reduced when the settlement was created.
      # settler (transaction.user) originally owed settles_user (transaction.settles_user).
      debt_result = Debts::UpdateBalance.call(
        debtor_user:  transaction.user,
        payer_user:   transaction.settles_user,
        amount_cents: transaction.amount_cents
      )

      raise ActiveRecord::Rollback if debt_result.failure?

      transaction.destroy!
    end

    Success()
  rescue ActiveRecord::RecordInvalid => e
    Failure(errors: e.record.errors.to_hash)
  end
end

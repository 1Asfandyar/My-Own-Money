# frozen_string_literal: true

class Transaction::Settlement::Destroy < ApplicationService
  def call(transaction:)
    @transaction = transaction
    reverse
  end

  private

  attr_reader :transaction

  def reverse
    ActiveRecord::Base.transaction do
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

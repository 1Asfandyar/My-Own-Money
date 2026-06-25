# frozen_string_literal: true

class Transaction::Shared::Destroy < ApplicationService
  include Transaction::Helpers

  def call(transaction:)
    @transaction = transaction
    reverse
  end

  private

  attr_reader :transaction

  def reverse
    ActiveRecord::Base.transaction do
      # Revert payer's account balance (full shared expense amount was deducted on creation)
      revert_account_balance(
        account:          transaction.account,
        transaction_type: :expense,
        amount_cents:     transaction.amount_cents
      )

      revert_payer_category_balance
      reverse_debts

      transaction.destroy!
    end

    Success()
  rescue ActiveRecord::RecordInvalid => e
    Failure(errors: e.record.errors.to_hash)
  rescue ActiveRecord::RecordNotDestroyed => e
    Failure(errors: { base: [ e.message ] })
  end

  # Category balance was updated by the payer's own share, not the full amount
  def revert_payer_category_balance
    payer_split = transaction.transaction_splits.find_by(user_id: transaction.user_id)
    return unless payer_split

    revert_category_balance(
      category:     transaction.category,
      amount_cents: payer_split.owed_amount_cents
    )
  end

  # For each non-payer split, the debt "participant → payer" must be reversed.
  # Calling UpdateBalance with (debtor: payer, payer: participant) triggers
  # adjust_reverse_debt, which nets the existing debt down by owed_amount_cents.
  def reverse_debts
    transaction.transaction_splits.where.not(user_id: transaction.user_id).find_each do |split|
      result = Debts::UpdateBalance.call(
        debtor_user:  transaction.user,
        payer_user:   split.user,
        amount_cents: split.owed_amount_cents
      )

      raise ActiveRecord::Rollback if result.failure?
    end
  end
end

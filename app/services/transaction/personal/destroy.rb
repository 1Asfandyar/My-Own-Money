# frozen_string_literal: true

class Transaction::Personal::Destroy < ApplicationService
  include Transaction::Helpers

  def call(transaction:)
    @transaction = transaction
    execute
  end

  private

  attr_reader :transaction

  def execute
    ActiveRecord::Base.transaction do
      revert_account_balance(
        account:          transaction.account,
        transaction_type: transaction.transaction_type,
        amount_cents:     transaction.amount_cents
      )
      revert_category_balance(
        category:     transaction.category,
        amount_cents: transaction.amount_cents
      )
      transaction.destroy!
    end
    Success(true)
  rescue ActiveRecord::RecordNotDestroyed => e
    Failure(errors: { base: [ e.message ] })
  end
end

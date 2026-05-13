# frozen_string_literal: true

module Debts
  class UpdateBalance < ApplicationService
    # debtor_user: the user who owes money
    # payer_user:  the user who is owed money
    # amount_cents: how much the debtor now owes the payer (must be positive)
    def call(debtor_user:, payer_user:, amount_cents:)
      return Success() if debtor_user.id == payer_user.id

      existing = find_existing_debt(debtor_user.id, payer_user.id)

      if existing.nil?
        create_debt(debtor_user.id, payer_user.id, amount_cents)
      elsif same_direction?(existing, debtor_user.id, payer_user.id)
        increase_debt(existing, amount_cents)
      else
        adjust_reverse_debt(existing, debtor_user.id, payer_user.id, amount_cents)
      end
    rescue ActiveRecord::RecordInvalid => e
      Failure(errors: e.record.errors.to_hash)
    end

    private

    def find_existing_debt(debtor_id, payer_id)
      Debt.where(from_user_id: debtor_id, to_user_id: payer_id)
          .or(Debt.where(from_user_id: payer_id, to_user_id: debtor_id))
          .first
    end

    def same_direction?(debt, debtor_id, payer_id)
      debt.from_user_id == debtor_id && debt.to_user_id == payer_id
    end

    def create_debt(debtor_id, payer_id, amount_cents)
      debt = Debt.create!(from_user_id: debtor_id, to_user_id: payer_id, amount_cents: amount_cents)
      Success(debt)
    end

    def increase_debt(debt, amount_cents)
      debt.update!(amount_cents: debt.amount_cents + amount_cents)
      Success(debt)
    end

    # existing debt runs payer → debtor (opposite direction); net against it
    def adjust_reverse_debt(existing, debtor_id, payer_id, amount_cents)
      net = existing.amount_cents - amount_cents

      if net > 0
        existing.update!(amount_cents: net)
      elsif net == 0
        existing.update!(amount_cents: 0)
      else
        # direction flips: debtor now owes payer
        existing.update!(from_user_id: debtor_id, to_user_id: payer_id, amount_cents: -net)
      end

      Success(existing)
    end
  end
end

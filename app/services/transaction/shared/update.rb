# frozen_string_literal: true

class Transaction::Shared::Update < ApplicationService
  include Transaction::Helpers

  # shared_by_users: array of User records (equal split only)
  # user_shares:     array of { user_id:, share: } (non-equal splits)
  # If neither is provided, participants are reconstructed from the existing splits.
  def call(transaction:, paid_by_user:, split_method:, amount_cents:,
           account:, category:, shared_by_users: nil, user_shares: nil,
           title: nil, transaction_date: nil, note: nil, currency: nil)
    @transaction      = transaction
    @paid_by_user     = paid_by_user
    @split_method     = split_method.to_s
    @amount_cents     = amount_cents
    @account          = account
    @category         = category
    @shared_by_users  = shared_by_users
    @user_shares      = user_shares
    @title            = title
    @transaction_date = transaction_date
    @note             = note
    @currency         = currency

    persist
  end

  private

  attr_reader :transaction, :paid_by_user, :split_method, :amount_cents,
              :account, :category, :shared_by_users, :user_shares,
              :title, :transaction_date, :note, :currency

  def persist
    old_splits       = transaction.transaction_splits.to_a
    old_payer        = transaction.user
    old_account      = transaction.account
    old_amount_cents = transaction.amount_cents
    debt_result      = nil

    ActiveRecord::Base.transaction do
      # 1. Reverse old debts by swapping debtor/payer to net each split to zero
      debt_result = reverse_debts!(old_splits, old_payer)
      raise ActiveRecord::Rollback if debt_result.failure?

      # 2. Revert old account balance
      revert_account_balance(account: old_account, transaction_type: :expense, amount_cents: old_amount_cents)

      # 3. Delete old splits
      transaction.transaction_splits.destroy_all

      # 4. Update transaction record
      transaction.update!(update_params)

      # 5. Calculate and create new splits
      splits = calculate_splits(old_splits)
      create_splits!(splits)

      # 6. Apply new account balance
      update_account_balance(account: account.reload, transaction_type: :expense, amount_cents: amount_cents)

      # 7. Apply new debts
      debt_result = apply_debts!(splits)
      raise ActiveRecord::Rollback if debt_result.failure?
    end

    return debt_result if debt_result&.failure?

    Success(transaction.reload)
  rescue ActiveRecord::RecordInvalid => e
    Failure(errors: e.record.errors.to_hash)
  end

  def reverse_debts!(old_splits, old_payer)
    old_splits.each do |split|
      next if split.user_id == old_payer.id

      debtor = User.find(split.user_id)
      # Swap debtor/payer so the existing debt nets to zero
      result = Debts::UpdateBalance.call(
        debtor_user:  old_payer,
        payer_user:   debtor,
        amount_cents: split.owed_amount_cents
      )
      return result if result.failure?
    end

    Success()
  end

  def calculate_splits(old_splits)
    if split_method == "equal"
      user_ids = shared_by_users&.map(&:id) || old_splits.map(&:user_id)
      Transaction::Splits::Calculator.calculate(
        method:       split_method,
        amount_cents: amount_cents,
        user_ids:     user_ids
      )
    else
      effective_shares = user_shares || reconstruct_user_shares(old_splits)
      Transaction::Splits::Calculator.calculate(
        method:       split_method,
        amount_cents: amount_cents,
        user_shares:  effective_shares
      )
    end
  end

  # Rebuild split inputs from persisted splits when the caller did not supply new participants.
  def reconstruct_user_shares(old_splits)
    case split_method
    when "exact"
      old_splits.map { |s| { user_id: s.user_id, share: s.owed_amount_cents } }
    when "percentage", "shares"
      old_splits.map { |s| { user_id: s.user_id, share: s.allocation_value.to_f } }
    else
      []
    end
  end

  def create_splits!(splits)
    splits.each do |split|
      transaction.transaction_splits.create!(
        user_id:           split[:user_id],
        split_method:      split[:split_method],
        owed_amount_cents: split[:owed_amount_cents],
        allocation_value:  split[:allocation_value]
      )
    end
  end

  def apply_debts!(splits)
    user_map = User.where(id: splits.map { |s| s[:user_id] }).index_by(&:id)

    splits.each do |split|
      next if split[:user_id] == paid_by_user.id

      debtor = user_map[split[:user_id]]
      result = Debts::UpdateBalance.call(
        debtor_user:  debtor,
        payer_user:   paid_by_user,
        amount_cents: split[:owed_amount_cents]
      )
      return result if result.failure?
    end

    Success()
  end

  def update_params
    {
      user:             paid_by_user,
      account:          account,
      category:         category,
      amount_cents:     amount_cents,
      title:            title,
      transaction_date: transaction_date,
      note:             note,
      currency:         currency
    }.compact
  end
end

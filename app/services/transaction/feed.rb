# frozen_string_literal: true

# Formats a pre-loaded Transaction collection into the unified feed shape.
# Returns Success(Array<Hash>).
#
# Every transaction type produces the same top-level keys. Type-specific
# rendering data lives in `display`:
#
#   personal expense / income  → display.account, .category, .payer
#   transfer                   → display.account (from), .transfer_to_account (to), .payer
#   settlement                 → display.account, .payer (settler), .settles_user (creditor)
#   shared expense             → display.account, .category, .payer, .my_split, .splits[]
#
# Caller must eager-load before passing transactions:
#   includes(:user, :account, :category, :currency, :group,
#            :settles_user, :transfer_account,
#            transaction_splits: [:user, :category])
class Transaction::Feed < ApplicationService
  def call(transactions, current_user_id:)
    @current_user_id = current_user_id
    Success(transactions.map { |txn| format(txn) })
  end

  private

  attr_reader :current_user_id

  def format(txn)
    {
      id:                  txn.id,
      title:               txn.title,
      amount_cents:        txn.amount_cents,
      transaction_type:    txn.transaction_type,
      visibility_type:     txn.visibility_type,
      transaction_date:    txn.transaction_date,
      note:                txn.note,
      account_id:          txn.account_id,
      transfer_account_id: txn.transfer_account_id,
      category_id:         txn.category_id,
      settles_user_id:     txn.settles_user_id,
      group_id:            txn.group_id,
      currency_id:         txn.currency_id,
      user_id:             txn.user_id,
      created_at:          txn.created_at,
      updated_at:          txn.updated_at,
      display:             build_display(txn)
    }
  end

  def build_display(txn)
    {
      account:             account_info(txn.account),
      category:            category_info(txn.category),
      payer:               user_info(txn.user),
      settles_user:        user_info(txn.settles_user),
      transfer_to_account: account_info(txn.transfer_account),
      my_split:            my_split(txn) && formate_split_info(my_split(txn)),
      splits:              splits_info(txn)
    }
  end

  def account_info(account)
    return nil unless account

    { id: account.id, name: account.name }
  end

  def category_info(category)
    return nil unless category

    { id: category.id, name: category.name, icon: category.icon, color: category.color }
  end

  def user_info(user)
    return nil unless user

    { id: user.id, full_name: user.full_name }
  end

  # Pure Ruby iteration over the already-loaded association — no extra queries.
  def splits_info(txn)
    return nil unless txn.transaction_splits.count > 0
    txn.transaction_splits.map { |split| formate_split_info(split) }
  end

  def my_split(txn)
    return nil unless txn.transaction_splits.count > 0
    txn.transaction_splits.find { |s| s.user_id == current_user_id }
  end

  def formate_split_info(split)
    {
      user_id:           split.user_id,
      full_name:         split.user.full_name,
      owed_amount_cents: split.owed_amount_cents,
      split_method:      split.split_method,
      allocation_value:  split.allocation_value
    }
  end
end

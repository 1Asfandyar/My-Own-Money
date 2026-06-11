# frozen_string_literal: true

# Formats a pre-loaded Transaction collection into the unified response shape
# defined in docs/TRANSACTION_RESPONSE_FORMAT.md.
#
# Caller must eager-load before passing transactions:
#   includes(:user, :account, :category, :currency,
#            :settles_user, :transfer_account,
#            transaction_splits: [:user, :category])
class Transaction::Formatter < ApplicationService
  RENDER_AS = {
    %i[expense personal owner]       => "personal_expense",
    %i[income personal owner]       => "personal_income",
    %i[transfer personal owner]       => "transfer",
    %i[expense shared payer]       => "shared_expense_payer",
    %i[expense shared participant] => "shared_expense_participant",
    %i[settlement shared settler]     => "settlement_settler",
    %i[settlement shared settlee]     => "settlement_settlee"
  }.freeze

  def call(transactions, current_user_id:)
    @current_user_id = current_user_id
    Success(transactions.map { |txn| format(txn) })
  end

  private

  attr_reader :current_user_id

  def format(txn)
    role = viewer_role(txn)
    {
      id:                  txn.id,
      type:                txn.transaction_type,
      visibility:          txn.visibility_type,
      title:               txn.title,
      note:                txn.note,
      date:                txn.transaction_date.iso8601,
      currency:            { code: txn.currency.code, symbol: txn.currency.symbol },
      amount_cents:        txn.amount_cents,
      render_as:           render_as(txn, role),
      viewer_role:         role,
      summary:             build_summary(txn, role),
      paid_by:             build_paid_by(txn),
      account:             { id: txn.account.id, name: txn.account.name },
      transfer_to_account: txn.transfer_account&.then { |a| { id: a.id, name: a.name } },
      category:            txn.category&.then { |c| { id: c.id, name: c.name } },
      counterpart:         build_counterpart(txn, role),
      split_method:        (txn.shared? && txn.expense?) ? txn.split_method : nil,
      splits:              build_splits(txn)
    }
  end

  def viewer_role(txn)
    if txn.shared? && txn.expense?
      txn.user_id == current_user_id ? :payer : :participant
    elsif txn.settlement?
      txn.user_id == current_user_id ? :settler : :settlee
    else
      :owner
    end
  end

  def render_as(txn, role)
    RENDER_AS[[ txn.transaction_type.to_sym, txn.visibility_type.to_sym, role ]]
  end

  def build_summary(txn, role)
    case role
    when :payer
      viewer_split = txn.transaction_splits.find { |s| s.user_id == current_user_id }
      lent = txn.amount_cents - viewer_split.owed_amount_cents
      { label: "you lent", amount_cents: lent, paid_by_label: "You" }
    when :participant
      my_split = txn.transaction_splits.find { |s| s.user_id == current_user_id }
      { label: "you owe", amount_cents: my_split.owed_amount_cents, paid_by_label: txn.user.full_name }
    when :settler
      { label: "you paid back", amount_cents: txn.amount_cents, paid_by_label: "You" }
    when :settlee
      { label: "you received", amount_cents: txn.amount_cents, paid_by_label: txn.user.full_name }
    when :owner
      label = txn.income? ? "you received" : txn.transfer? ? "you transferred" : "you paid"
      { label: label, amount_cents: txn.amount_cents, paid_by_label: "You" }
    end
  end

  def build_paid_by(txn)
    payer = txn.user
    { id: payer.id, name: payer.full_name, is_you: payer.id == current_user_id }
  end

  def build_counterpart(txn, role)
    return nil unless txn.settlement?

    other = role == :settler ? txn.settles_user : txn.user
    { id: other.id, name: other.full_name }
  end

  def build_splits(txn)
    return nil unless txn.shared? && txn.expense?

    splits = txn.transaction_splits.to_a
    viewer, others = splits.partition { |s| s.user_id == current_user_id }
    (viewer + others.sort_by { |s| s.user.full_name }).map do |s|
      {
        user:              { id: s.user.id, name: s.user.full_name, is_you: s.user_id == current_user_id },
        owed_amount_cents: s.owed_amount_cents,
        allocation_value:  s.allocation_value&.to_f,
        category:          s.category ? { id: s.category.id, name: s.category.name } : nil
      }
    end
  end
end

# frozen_string_literal: true

# Builds and returns a filtered Transaction relation visible to `current_user`.
#
# Visibility rule: a transaction is "owned" by the user when they are the
# creator (transactions.user_id), a split participant (transaction_splits.user_id),
# or the settlee of a settlement (transactions.settles_user_id).
#
# Accepted filters (all optional, nil/blank = ignored):
#   account_id       – restrict to a single source account
#   category_id      – match transactions.category_id OR the user's own
#                      transaction_splits.category_id for shared expenses
#   friend_id        – only return transactions where both the current user
#                      AND this user appear as participants
#   transaction_type – :expense | :income | :transfer | :settlement
#   visibility_type  – :personal | :shared
#   group_id         – shared expenses belonging to a specific group
#   date_from        – lower bound on transaction_date (inclusive)
#   date_to          – upper bound on transaction_date (inclusive)
#   search           – ILIKE match against title or note
#   page / per_page  – pagination (defaults: 1 / 25)
class Transaction::Query < ApplicationService
  DEFAULT_PER_PAGE = 25

  def call(
    current_user:,
    account_id: nil,
    category_id: nil,
    friend_id: nil,
    transaction_type: nil,
    visibility_type: nil,
    group_id: nil,
    date_from: nil,
    date_to: nil,
    search: nil,
    page: 1,
    per_page: DEFAULT_PER_PAGE
  )
    @current_user     = current_user
    @account_id       = account_id
    @category_id      = category_id
    @friend_id        = friend_id
    @transaction_type = transaction_type
    @visibility_type  = visibility_type
    @group_id         = group_id
    @date_from        = date_from
    @date_to          = date_to
    @search           = search
    # TODO: user peggy gem for pagination metadata instead of manual limit/offset
    @page             = (page || 1).to_i
    @per_page         = per_page.nil? ? nil : (per_page || DEFAULT_PER_PAGE).to_i

    Success(build_scope)
  end

  private

  attr_reader :current_user, :account_id, :category_id, :friend_id,
              :transaction_type, :visibility_type, :group_id,
              :date_from, :date_to, :search, :page, :per_page

  # One LEFT JOIN + one WHERE + DISTINCT covers all three ownership cases.
  def base_scope
    Transaction
      .left_joins(:transaction_splits)
      .where(user_visible_condition, uid: current_user.id)
      .distinct
  end

  def user_visible_condition
    <<~SQL.squish
      transactions.user_id            = :uid
      OR transaction_splits.user_id   = :uid
      OR transactions.settles_user_id = :uid
    SQL
  end

  def build_scope
    scope = base_scope
    scope = apply_friend_filter(scope)
    scope = apply_scalar_filters(scope)
    scope = apply_category_filter(scope)
    scope = apply_date_filters(scope)
    scope = apply_search_filter(scope)
    scope = eager_load(scope)
    scope = scope.order(transaction_date: :desc)
    return scope unless @per_page
    scope.offset((@page - 1) * @per_page).limit(@per_page)
  end

  # Matches transactions shared between current_user and friend:
  # shared expenses (friend appears in splits) OR settlements between the two.
  def apply_friend_filter(scope)
    return scope if friend_id.blank?

    friend_split_tx_ids = TransactionSplit.where(user_id: friend_id).select(:transaction_id)

    scope.where(
      "transactions.id IN (?) OR (transactions.user_id = ? AND transactions.settles_user_id = ?) OR (transactions.user_id = ? AND transactions.settles_user_id = ?)",
      friend_split_tx_ids, friend_id, current_user.id, current_user.id, friend_id
    )
  end

  def apply_scalar_filters(scope)
    scope = scope.where(account_id:       account_id)       if account_id.present?
    scope = scope.where(transaction_type: transaction_type) if transaction_type.present?
    scope = scope.where(visibility_type:  visibility_type)  if visibility_type.present?
    scope = scope.where(group_id:         group_id)         if group_id.present?
    scope
  end

  # Matches payer's category on the transaction OR the user's personal category
  # on their split row — covers shared expenses where the user is not the payer.
  def apply_category_filter(scope)
    return scope if category_id.blank?

    scope.where(
      "transactions.category_id = :cid OR (transaction_splits.user_id = :uid AND transaction_splits.category_id = :cid)",
      cid: category_id, uid: current_user.id
    )
  end

  def apply_date_filters(scope)
    if date_from.present?
      parsed = date_from.is_a?(Time) ? date_from : Time.parse(date_from.to_s)
      scope = scope.where("transactions.transaction_date >= ?", parsed)
    end
    if date_to.present?
      parsed = date_to.is_a?(Time) ? date_to : Time.parse(date_to.to_s)
      scope = scope.where("transactions.transaction_date <= ?", parsed)
    end
    scope
  end

  def apply_search_filter(scope)
    return scope if search.blank?

    term = "%#{search}%"
    scope.where("transactions.title ILIKE ? OR transactions.note ILIKE ?", term, term)
  end

  def eager_load(scope)
    scope.includes(
      { user: :currency }, :account, :category, :group,
      :settles_user, :transfer_account,
      transaction_splits: [ :user, :category ]
    )
  end
end

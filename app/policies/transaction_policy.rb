class TransactionPolicy
  attr_reader :current_user, :record

  def initialize(current_user, record)
    @current_user = current_user
    @record       = record
  end

  def index?   = current_user.present?
  def show?    = visible?
  def create?  = current_user.present?
  def update?  = owner?
  def destroy? = owner?

  private

  def owner?
    record.user_id == current_user.id
  end

  def visible?
    owner? ||
      record.settles_user_id == current_user.id ||
      record.transaction_splits.any? { |s| s.user_id == current_user.id } ||
      (record.group_id.present? && current_user.group_ids.include?(record.group_id))
  end
end

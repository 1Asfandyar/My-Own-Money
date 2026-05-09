class AccountPolicy
  attr_reader :current_user, :record

  def initialize(current_user, record)
    @current_user = current_user
    @record       = record
  end

  def index?   = current_user.present?
  def create?  = current_user.present?
  def show?    = owner?
  def update?  = owner?
  def destroy? = owner?

  private

  def owner?
    record.user_id == current_user.id
  end
end

class GroupPolicy
  attr_reader :current_user, :record

  def initialize(current_user, record)
    @current_user = current_user
    @record       = record
  end

  def create?        = current_user.present?
  def update?        = member?
  def destroy?       = member?
  def add_members?   = member?
  def remove_member? = member?
  def leave?         = member?

  private

  def member?
    record.users.exists?(id: current_user.id)
  end
end

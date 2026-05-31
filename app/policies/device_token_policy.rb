class DeviceTokenPolicy
  attr_reader :current_user, :record

  def initialize(current_user, record)
    @current_user = current_user
    @record       = record
  end

  def create?  = current_user.present?
  def destroy? = owner?

  private

  def owner?
    record.user_id == current_user.id
  end
end

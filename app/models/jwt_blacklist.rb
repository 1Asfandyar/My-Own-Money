# == Schema Information
#
# Table name: jwt_blacklists
#
#  id         :bigint           not null, primary key
#  exp        :datetime
#  jti        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class JwtBlacklist < ApplicationRecord
  self.table_name = "jwt_blacklists"

  def self.jwt_revoked?(payload, _opts)
    exists?(jti: payload["jti"])
  end

  def self.revoke_jwt(payload, _opts)
    create(jti: payload["jti"], exp: Time.zone.at(payload["exp"]))
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at exp id jti updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end
end

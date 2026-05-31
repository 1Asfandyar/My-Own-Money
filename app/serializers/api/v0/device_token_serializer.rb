module Api::V0
  class DeviceTokenSerializer < Blueprinter::Base
    identifier :id

    fields :token, :platform, :user_id, :created_at, :updated_at
  end
end

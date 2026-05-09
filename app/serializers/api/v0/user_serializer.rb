module Api::V0
  class UserSerializer < Blueprinter::Base
    identifier :id

    fields :full_name, :mobile_number, :email, :role, :created_at, :updated_at
  end
end

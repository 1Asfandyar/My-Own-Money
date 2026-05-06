module Api
  module V1
    class UserSerializer < Blueprinter::Base
      identifier :id

      fields :full_name, :mobile_number, :email, :role, :created_at, :updated_at

      view :index do
        fields :full_name, :mobile_number, :email, :role, :created_at, :updated_at
      end

      view :show do
        fields :full_name, :mobile_number, :email, :role, :created_at, :updated_at
      end
    end
  end
end

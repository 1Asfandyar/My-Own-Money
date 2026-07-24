module Api::V0
  class UserSerializer < Blueprinter::Base
    identifier :id

    fields :full_name, :mobile_number, :email, :role, :onboarding_completed, :currency_id, :created_at, :updated_at

    field :currency_symbol do |user|
      user.currency&.symbol
    end
  end
end

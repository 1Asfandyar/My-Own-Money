module Api::V0
  class AccountSerializer < Blueprinter::Base
    identifier :id

    fields :name, :current_balance_cents, :initial_balance_cents, :is_archived,
           :user_id, :created_at, :updated_at

    field :currency_symbol do |account|
      account.user.currency&.symbol
    end
  end
end

module Api::V0
  class AccountSerializer < Blueprinter::Base
    identifier :id

    fields :name, :current_balance_cents, :initial_balance_cents, :is_archived,
           :currency_id, :user_id, :created_at, :updated_at
  end
end

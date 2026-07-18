module Api::V0
  class TransactionSerializer < Blueprinter::Base
    identifier :id

    fields :title, :amount_cents, :transaction_type, :visibility_type,
           :transaction_date, :note, :account_id, :transfer_account_id,
           :category_id, :settles_user_id, :user_id, :created_at, :updated_at

    field :currency_symbol do |transaction|
      transaction.user.currency&.symbol
    end

    view :with_categories do
      excludes :split_amount_cents
    end

    view :with_category do
      association :category, blueprint: Api::V0::CategorySerializer
    end
  end
end

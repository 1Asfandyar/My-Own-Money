module Api::V0
  class CategorySerializer < Blueprinter::Base
    identifier :id

    fields :name, :icon, :color, :category_type, :balance_cents, :user_id, :created_at, :updated_at
  end
end

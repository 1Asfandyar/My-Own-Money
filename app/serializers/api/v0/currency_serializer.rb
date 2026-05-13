module Api::V0
  class CurrencySerializer < Blueprinter::Base
    identifier :id

    fields :code, :name, :symbol, :created_at, :updated_at
  end
end

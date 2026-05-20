module Api::V0
  class GroupSerializer < Blueprinter::Base
    identifier :id

    fields :name, :description, :created_by_id, :created_at, :updated_at

    association :users, blueprint: Api::V0::UserSerializer, name: :members
  end
end

module Api::V0
  class GroupSerializer < Blueprinter::Base
    identifier :id

    fields :name, :description, :created_by_id, :created_at, :updated_at

    association :members, blueprint: Api::V0::UserSerializer do |group, _options|
      group.users
    end
  end
end

# frozen_string_literal: true

ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    columns do
      column do
        panel "Overview" do
          h3 "Users: #{User.count}"
          h3 "Admin users: #{AdminUser.count}"
          h3 "Revoked tokens: #{JwtBlacklist.count}"
        end
      end

      column do
        panel "Recent Users" do
          table_for User.order(created_at: :desc).limit(5) do
            column :id
            column :email
            column :role
            column :created_at
          end
        end
      end
    end
  end # content
end

ActiveAdmin.register User do
  permit_params :full_name, :mobile_number, :email, :password, :password_confirmation, :role

  index do
    selectable_column
    id_column
    column :full_name
    column :mobile_number
    column :email
    column :role
    column :created_at
    actions
  end

  filter :full_name
  filter :mobile_number
  filter :email
  filter :role, as: :select, collection: User.roles
  filter :created_at

  form do |f|
    f.inputs do
      f.input :full_name
      f.input :mobile_number
      f.input :email
      f.input :role, as: :select, collection: User.roles.keys
      f.input :password
      f.input :password_confirmation
    end
    f.actions
  end

  controller do
    def update
      if params.dig(:user, :password).blank?
        params[:user].delete(:password)
        params[:user].delete(:password_confirmation)
      end

      super
    end
  end
end

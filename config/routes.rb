Rails.application.routes.draw do
  devise_for :users, skip: :all
  devise_for :admin_users, ActiveAdmin::Devise.config

  ActiveAdmin.application.load!
  admin_resources = ActiveAdmin.application.namespaces[:admin].resources
  comment_resource = admin_resources[ActiveAdmin::Comment] if defined?(ActiveAdmin::Comment)
  admin_resources.instance_variable_get(:@collection).delete(comment_resource.resource_name) if comment_resource
  ActiveAdmin::Router.new(router: self, namespaces: ActiveAdmin.application.namespaces).apply

  get "up" => "health#show", as: :rails_health_check

  draw :api_v0

  root to: redirect("/admin")
end

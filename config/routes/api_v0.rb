namespace :api do
  namespace :v0 do
    post "auth/signup", to: "auth#signup"
    post "auth/login",  to: "auth#login"
    delete "auth/logout", to: "auth#logout"

    get   "me", to: "users#me"
    patch "me", to: "users#update_me"

    resources :currencies, only: [ :index ]
    resources :accounts
    resources :categories

    resources :transactions

    resources :groups do
      member do
        post   "members",          to: "groups#add_members"
        delete "members/:user_id", to: "groups#remove_member"
        delete "leave",            to: "groups#leave"
      end
    end
  end
end

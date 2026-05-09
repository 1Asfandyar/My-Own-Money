namespace :api do
  namespace :v0 do
    post "auth/signup", to: "auth#signup"
    post "auth/login",  to: "auth#login"
    delete "auth/logout", to: "auth#logout"

    get   "me", to: "users#me"
    patch "me", to: "users#update_me"

    resources :accounts
  end
end

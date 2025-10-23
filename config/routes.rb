Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root path - Dashboard is home
  root 'dashboard#show'

  # Dashboard
  resource :dashboard, only: :show

  # Applications - manual JD entry and list
  resources :applications, only: %i[index new create show] do
    collection do
      post :quick_create
      post :prepare
      post :finalize
    end
    member do
      get :resume, to: 'applications#download_resume'
      get :cover_letter, to: 'applications#download_cover_letter'
    end
  end

  # Files - dev-only reveal in Finder
  namespace :files do
    post :reveal, to: 'reveal#create'
  end

  # Jobs - fetched job board
  resources :jobs, only: %i[index show] do
    collection do
      post :fetch
    end

    member do
      post :tailor
      patch :applied
      patch :rejected
      patch :exported
      patch :ignore
      patch :snooze
      patch :update_notes
    end

    resources :job_skill_assessments, only: %i[create update]
  end

  # Filters and settings
  post 'filters/block_company', to: 'filters#block_company'

  namespace :settings do
    get :filters
    resources :blocked_companies, only: %i[create destroy]
  end

  # AI features
  namespace :ai do
    resources :usages, only: [:index]

    resources :jobs, only: [] do
      member do
        post :summarize
        post :skills
      end
    end
  end

  # Optional: Sidekiq web UI (dev only, requires Redis + Sidekiq gem)
  if Rails.env.development? && defined?(Sidekiq)
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end
end

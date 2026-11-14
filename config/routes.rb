# frozen_string_literal: true

Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  if Rails.env.development?
    require "sidekiq/web"
    mount Sidekiq::Web => "/sidekiq"
  end

  # Defines the root path route ("/")
  root "pages#home"
  get "subatomic_particles" => "pages#subatomic_particles", as: :subatomic_particles
  get "quantum_states" => "pages#quantum_states", as: :quantum_states

  resources :particle_groups, only: [] do
    post :populate, on: :collection
  end

  resources :subatomic_particles, only: [ :show ] do
    post :populate, on: :collection
    post :generate_embedding, on: :member
    post :populate_quantum_states, on: :member
  end

  resources :quantum_states, only: [ :show ] do
    post :populate, on: :collection
    post :generate_embedding, on: :member
  end

  resources :clusters, only: [ :index ] do
    post :snapshot, on: :collection
  end

  resources :cluster_snapshots, only: [ :index, :show, :destroy ] do
    resources :cluster_reports, only: [ :create ]
  end

  resources :cluster_reports, path: "reports", only: [ :index, :show, :destroy ] do
    post :deep_synthesis, on: :member
  end

  resource :settings, only: [ :show ] do
    post :generate_embeddings, on: :collection
    patch :update_context_window, on: :collection
  end

  # ==========================================
  # Programmatic REST API (v1)
  # ==========================================
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      get "status" => "status#show"
      get "openapi" => "openapi#show", as: :openapi_spec
      get "search" => "search#index"

      resources :particle_groups do
        collection do
          post :upsert_batch
          post :populate
        end
        member do
          post :populate_subatomic_particles
        end
      end

      resources :subatomic_particles do
        collection do
          get :search
          post :upsert_batch
          post :populate
        end
        member do
          get :neighbors
          post :generate_embedding
          post :populate_quantum_states
        end
      end

      resources :quantum_states do
        collection do
          get :search
          post :upsert_batch
          post :populate
        end
        member do
          get :neighbors
          post :generate_embedding
        end
      end

      resources :clusters, only: [ :index ] do
        collection do
          post :snapshot
        end
      end

      resources :cluster_snapshots, only: [ :index, :show, :create, :destroy ] do
        resources :cluster_groups, only: [ :index ]
        resources :cluster_reports, only: [ :create ]
      end

      resources :cluster_groups, only: [ :show ]

      resources :cluster_reports, only: [ :index, :show, :create, :destroy ] do
        member do
          post :deep_synthesis
        end
        resources :summaries, controller: :cluster_report_summaries, only: [ :index ]
        resources :sub_reports, controller: :cluster_sub_reports, only: [ :index ]
      end

      resources :cluster_report_summaries, only: [ :show ]
      resources :cluster_sub_reports, only: [ :show ]

      resources :jobs, only: [ :index, :show ]

      resource :settings, only: [ :show ] do
        patch :context_window, action: :update_context_window
        post :generate_embeddings
      end
    end
  end
end

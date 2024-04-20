Rails.application.routes.draw do
  devise_for :users

  root "time_regs#index"

  resources :onboarding, only: [ :new, :create ]

  resources :project_reports do
    patch :update_group
    collection do
      get "update_projects_select"
      get "update_members_checkboxes"
      get "update_tasks_checkboxes"
      post "export"
      get ":id/detailed", to: "project_reports#detailed", as: :detailed_project_report
    end
  end

  resources :user_reports do
    patch :update_group
    collection do
      post "export"
      get "update_projects_checkboxes"
      get "update_tasks_checkboxes"
    end
  end

  resource :report, only: [ :show, :update ]

  resources :clients

  resources :tasks

  match "projects/import" => "projects#import", :via => :post
  resources :time_regs do
    patch :toggle_active
    collection do
      get "export"
      post "import"
      get "update_tasks_select"
    end
    post :new_modal, on: :collection
    put :edit_modal, on: :member
    post :delete_confirmation, on: :member
  end

  resources :projects, except: [ :index ] do
    resources :memberships
    resources :assigned_tasks
    get "export", to: "projects#export", as: "export_project_time_reg"
  end

  namespace :workspace do
    resources :projects do
      post :import_modal, on: :collection
      post :new_modal, on: :collection
      post :delete_confirmation, on: :member
      put :edit_modal, on: :member

      scope module: :projects do
        resources :memberships do
          post :new_modal, on: :collection
          post :delete_confirmation, on: :member
        end

        resources :assigned_tasks do
          post :new_modal, on: :member
          post :delete_confirmation, on: :member
        end

        resource :tasks do
          post :new_modal, on: :member
        end
      end
    end

    resources :clients do
      post :new_modal, on: :collection
      post :edit_modal, on: :member
      post :delete_confirmation, on: :member
    end
    resources :tasks, only: [ :index ]
    resources :teams, only: [ :index ]
  end
end

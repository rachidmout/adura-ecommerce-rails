Rails.application.routes.draw do
  post "/webhooks/stripe", to: "stripe_webhooks#create"

  # Ancienne URL publique du catalogue. Le catalogue canonique est
  # /parfums : conserver cette redirection permanente évite les 404 pour
  # les liens historiques déjà connus des moteurs de recherche.
  get "/products", to: redirect("/parfums", status: 301), as: :legacy_products

  namespace :ai do
    get "/catalogue", to: "catalogues#show", as: :catalogue, defaults: { format: :json }
    post "/video_jobs", to: "video_jobs#create", as: :video_jobs, defaults: { format: :json }
  end

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      namespace :growth do
        resource :dashboard, only: :show
      end
    end
  end

  # Préfixe de langue optionnel devant toutes les routes publiques :
  # "/parfums" (français, par défaut) et "/en/parfums" (anglais) pointent
  # vers le même contrôleur. Le "(:locale)" entre parenthèses le rend
  # facultatif, donc les URL françaises existantes ne changent pas.
  scope "(:locale)", locale: /en|es|de|it|nl|fr/ do
    root "home#index"

    get "/parfums", to: "products#index", as: :products
    get "/parfums-gourmands", to: "commercial_pages#show", defaults: { page_key: "gourmands" }, as: :gourmand_perfumes
    get "/parfums-lattafa", to: "commercial_pages#show", defaults: { page_key: "lattafa" }, as: :lattafa_perfumes
    get "/parfums-dubai", to: "commercial_pages#show", defaults: { page_key: "dubai" }, as: :dubai_perfumes
    get "/parfums/famille/:slug", to: "products#index", as: :family_catalog
    get "/parfums/genre/:audience", to: "products#index", as: :audience_catalog, constraints: { audience: /femme|homme|mixte/ }
    get "/parfums/:slug", to: "products#show", as: :product
    post "/parfums/:product_slug/avis", to: "reviews#create", as: :product_reviews

    get "/trouver-mon-parfum", to: "quiz#show", as: :quiz
    post "/trouver-mon-parfum/resultats", to: "quiz#results", as: :quiz_results

    resource :cart, only: :show, path: "panier"
    resources :cart_items, only: %i[create update destroy], path: "articles-panier"
    resource :promo_code, only: %i[create destroy], path: "code-promo"
    resource :checkout, only: %i[new create], path: "commande" do
      get :shipping_options
      get :relay_points
    end
    get "/adresse/communes", to: "address_lookups#cities", as: :address_cities
    get "/commandes/:public_token/confirmation", to: "orders#show", as: :order_confirmation
    post "/commandes/:public_token/reprise", to: "orders#resume", as: :resume_order

    get "/a-propos", to: "static_pages#show", defaults: { page: "about" }, as: :about
    get "/faq", to: "static_pages#show", defaults: { page: "faq" }, as: :faq
    get "/contact", to: "static_pages#show", defaults: { page: "contact" }, as: :contact
    get "/livraison-et-retours", to: "static_pages#show", defaults: { page: "shipping" }, as: :shipping
    get "/retours-et-remboursements", to: "static_pages#show", defaults: { page: "returns" }, as: :returns
    get "/conditions-generales-de-vente", to: "static_pages#show", defaults: { page: "terms" }, as: :terms
    get "/confidentialite", to: "static_pages#show", defaults: { page: "privacy" }, as: :privacy
    get "/mentions-legales", to: "static_pages#show", defaults: { page: "legal" }, as: :legal
  end

  namespace :admin do
    root "dashboard#show"
    get "/connexion", to: "sessions#new", as: :login
    post "/connexion", to: "sessions#create"
    delete "/deconnexion", to: "sessions#destroy", as: :logout
    resources :products, path: "produits" do
      member do
        patch :publish, path: "publier"
        patch :archive, path: "archiver"
        post :duplicate, path: "dupliquer"
      end
      resources :variants, path: "variantes", except: :show do
        member { post :duplicate, path: "dupliquer" }
      end
      resources :images, path: "images", controller: "product_images", only: %i[create update destroy] do
        member do
          patch :set_primary, path: "principale"
          patch :move_up, path: "monter"
          patch :move_down, path: "descendre"
        end
      end
    end
    resources :catalog_variants, only: %i[index update], path: "catalogue-rapide"
    resources :marketing_video_jobs, only: %i[index show destroy], path: "videos-marketing" do
      member do
        patch :approve
        patch :reject
        patch :generate
      end
    end
    get "/analytics", to: "analytics#show", as: :analytics
    resource :shipping_configuration, only: :show, path: "livraison" do
      patch :packaging
    end
    resources :shipping_zones, path: "zones-livraison" do
      member do
        patch :activate
        patch :deactivate
      end
      resources :shipping_zone_countries, path: "pays", only: %i[create destroy]
      resources :shipping_methods, path: "methodes", only: %i[new create edit update destroy] do
        member do
          patch :activate
          patch :deactivate
        end
        resources :shipping_rates, path: "tarifs", only: %i[new create edit update destroy]
      end
    end
    resources :orders, only: %i[index show], path: "commandes" do
      member do
        patch :prepare, path: "preparer"
        patch :ship, path: "expedier"
        post :create_shipment, path: "creer-expedition"
        post :retry_shipment, path: "reessayer-expedition"
      end
    end
    resources :promo_codes, only: %i[index new create edit update]
    resources :reviews, only: %i[index destroy] do
      member do
        patch :approve
        patch :hide
      end
    end
    resources :olfactory_families, path: "familles", only: %i[index edit update]
    get "/seo", to: "seo#index", as: :seo
  end

  get "/sitemap.xml", to: "sitemaps#index", as: :sitemap, defaults: { format: "xml" }

  get "up" => "rails/health#show", as: :rails_health_check
end

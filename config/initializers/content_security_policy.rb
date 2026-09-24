Rails.application.config.content_security_policy do |policy|
  policy.default_src :self
  policy.font_src :self, :data
  # Les images produits sont servies par Active Storage via une redirection
  # (adura.store/rails/active_storage/... -> AWS_ENDPOINT) : les navigateurs
  # réévaluent la CSP sur la cible d'une redirection, donc l'origine R2 doit
  # être explicitement autorisée ici, pas seulement 'self'. Dérivé de la même
  # variable que storage.yml plutôt que codé en dur, pour rester synchronisé
  # si l'endpoint R2 change. Vide (donc absent de la policy) en dev/test, où
  # AWS_ENDPOINT n'est pas définie.
  policy.img_src(*[ :self, :data, :blob, ENV["AWS_ENDPOINT"].presence ].compact)
  policy.object_src :none
  policy.script_src :self, "https://www.googletagmanager.com"
  policy.style_src :self, :unsafe_inline
  policy.connect_src :self, "https://api.stripe.com", "https://www.google-analytics.com", "https://region1.google-analytics.com"
  policy.frame_src "https://checkout.stripe.com"
  policy.form_action :self, "https://checkout.stripe.com"
end

Rails.application.config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
Rails.application.config.content_security_policy_nonce_directives = %w[script-src]

module HomeHelper
  # Liste fermée : seules ces 4 icônes existent pour le bandeau de
  # réassurance de l'accueil. Un nom inconnu lève une erreur explicite
  # plutôt que d'afficher un SVG vide.
  TRUST_ICON_PATHS = {
    catalog: '<path d="m12 3 9 5-9 5-9-5 9-5Z" /><path d="m3 13 9 5 9-5" />',
    delivery: '<path d="M3 6h11v11H3zM14 10h4l3 3v4h-7z" /><circle cx="7" cy="18" r="2" /><circle cx="18" cy="18" r="2" />',
    authentic: '<path d="m12 3 2.2 2.2 3.1-.2.7 3 2.5 1.8-1.4 2.8.9 3-2.8 1.3-.7 3-3.1-.3L12 21l-2.2-2.2-3.1.3-.7-3L3.2 15l.9-3-1.4-2.8L5.2 8l.7-3 3.1.2L12 3Z" /><path d="m8.5 12 2.2 2.2 4.8-5" />',
    advice: '<path d="M5 18.5v-2.8a7 7 0 1 1 14 0v2.8" /><path d="M5 15H3v4h3M19 15h2v4h-3M16 20c-1 .7-2.3 1-4 1" />'
  }.freeze

  # Rendu SVG inline pour une icône du bandeau de réassurance. `name` doit
  # être l'une des 4 clés de TRUST_ICON_PATHS ci-dessus.
  # aria-hidden + focusable="false" : ces icônes sont purement décoratives,
  # le texte à côté d'elles porte déjà le sens (accessibilité).
  def trust_icon(name)
    path_data = TRUST_ICON_PATHS.fetch(name.to_sym) do
      raise ArgumentError, "icône de confiance inconnue : #{name.inspect} (attendu : #{TRUST_ICON_PATHS.keys.join(', ')})"
    end

    content_tag(:svg, raw(path_data), class: "trust-icon", viewBox: "0 0 24 24", "aria-hidden": "true", focusable: "false")
  end
end

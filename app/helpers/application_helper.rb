module ApplicationHelper
  TRACKING_URL_HOSTS = %w[
    www.laposte.fr
    www.chronopost.fr
    www.mondialrelay.fr
    www.dhl.com
    www.ups.com
    www.fedex.com
  ].freeze

  # Nom natif + drapeau affichés dans le sélecteur de langue, dans l'ordre
  # d'affichage voulu. Ajouter une langue ici + un fichier config/locales/*.yml
  # + l'ajouter à config.i18n.available_locales (config/application.rb) et à
  # la regex de config/routes.rb suffit à la faire apparaître partout.
  LOCALE_META = {
    fr: { name: "Français", flag: "🇫🇷" },
    en: { name: "English", flag: "🇬🇧" },
    es: { name: "Español", flag: "🇪🇸" },
    de: { name: "Deutsch", flag: "🇩🇪" },
    it: { name: "Italiano", flag: "🇮🇹" },
    nl: { name: "Nederlands", flag: "🇳🇱" }
  }.freeze

  COMMERCIAL_PAGE_ROUTE_HELPERS = {
    "gourmands" => :gourmand_perfumes,
    "lattafa" => :lattafa_perfumes,
    "dubai" => :dubai_perfumes
  }.freeze

  def money(cents, currency: "EUR")
    number_to_currency(cents.to_i / 100.0, unit: currency == "EUR" ? "€" : currency, format: "%n %u", separator: ",", delimiter: " ")
  end

  def commercial_page_path_for(key)
    public_send("#{COMMERCIAL_PAGE_ROUTE_HELPERS.fetch(key.to_s)}_path")
  end

  def commercial_page_url_for(key)
    public_send("#{COMMERCIAL_PAGE_ROUTE_HELPERS.fetch(key.to_s)}_url")
  end

  # Les valeurs d'enum restent techniques en base et dans les routes. Cette
  # méthode est le point unique de présentation des statuts de commande.
  # Un futur statut non traduit reste lisible plutôt que d'afficher une clé
  # I18n manquante.
  def order_status_label(status)
    value = status.to_s
    I18n.t("orders.statuses.#{value}", locale: :fr, default: value.humanize)
  end

  # lazy: false uniquement pour l'image principale déjà visible à l'écran
  # au chargement (ex. la photo de la fiche produit) — la retarder nuirait
  # au LCP au lieu d'aider. Partout ailleurs (cartes catalogue, panier,
  # produits liés), lazy: true par défaut.
  def product_image(product, class_name: nil, lazy: true, widths: nil, sizes: nil, fetchpriority: nil, **html_options)
    image = product.primary_image
    return tag.div(product.name, class: "bottle-placeholder") unless image&.file&.attached?

    responsive_product_image(
      image,
      class_name: class_name,
      lazy: lazy,
      widths: widths,
      sizes: sizes,
      fetchpriority: fetchpriority,
      **html_options
    )
  end

  # Les variantes Active Storage sont générées à la demande par vips puis
  # conservées sur le même service de stockage. Les originaux R2 ne sont donc
  # ni modifiés ni dupliqués manuellement, tout en évitant de servir une photo
  # 1 000 px à une carte affichée à 150 px sur mobile.
  def responsive_product_image(image, class_name: nil, lazy: true, widths: nil, sizes: nil, fetchpriority: nil, alt: nil, **html_options)
    return tag.div(class: "bottle-placeholder") unless image&.file&.attached?

    file = image.file
    widths = Array(widths).map(&:to_i).select(&:positive?).uniq.sort
    options = html_options.merge(
      alt: alt.nil? ? image.alt_text : alt,
      class: class_name,
      loading: lazy ? "lazy" : "eager",
      fetchpriority: fetchpriority
    ).compact

    return image_tag(file, **options) if widths.empty?

    options[:sizes] = sizes if sizes.present?
    options[:srcset] = widths.map { |width| "#{responsive_product_image_url(image, width: width)} #{width}w" }.join(", ")
    image_tag(file.variant(resize_to_limit: [ widths.last, widths.last ]), **options)
  end

  def responsive_product_image_url(image, width:)
    url_for(image.file.variant(resize_to_limit: [ width, width ]))
  end

  def translated_audience(code)
    { "women" => t("products.index.women"), "men" => t("products.index.men"), "unisex" => t("products.index.unisex") }.fetch(code, code)
  end

  # Le nom/la description des familles olfactives et des notes sont stockés
  # en français dans la base (OlfactoryFamily#name, OlfactoryNote#name). Les
  # traductions vivent dans config/locales/*.yml sous les clés
  # olfactory_families.<slug> / olfactory_notes.<slug>, indexées par slug
  # plutôt que par texte pour rester stables si le libellé français change.
  # default: renvoie le texte français si une traduction manque, plutôt que
  # de lever une erreur ou d'afficher une clé manquante.
  def translated_family_name(family)
    return nil if family.nil?
    return family.name if I18n.locale == :fr

    t("olfactory_families.#{family.slug}.name", default: family.name)
  end

  def translated_family_description(family)
    return nil if family.nil?
    return family.description if I18n.locale == :fr

    t("olfactory_families.#{family.slug}.description", default: family.description)
  end

  # Illustrations de app/assets/images/olfactory/ (mêmes fichiers que le
  # dossier public/images/olfactory du prototype, utilisé là-bas pour le
  # questionnaire olfactif). "tropical" n'existait pas dans ce jeu : dessinée
  # à la main dans le même style (fond dégradé 320×210, tracés organiques,
  # étincelle dorée signature) faute d'un visuel officiel à reprendre.
  FAMILY_ICONS = {
    "gourmand" => "olfactory/gourmand.svg",
    "floral" => "olfactory/floral.svg",
    "fruite" => "olfactory/fruite.svg",
    "boise" => "olfactory/boise.svg",
    "musc" => "olfactory/musc.svg",
    "tropical" => "olfactory/tropical.svg"
  }.freeze

  def family_icon(family, class_name: "family-icon")
    path = FAMILY_ICONS[family&.slug]
    return tag.span("✦", class: "family-icon-fallback", aria: { hidden: true }) unless path

    image_tag path, alt: "", class: class_name, aria: { hidden: true }
  end

  def translated_note_name(note)
    return nil if note.nil?
    return note.name if I18n.locale == :fr

    t("olfactory_notes.#{note.slug}.name", default: note.name)
  end

  # Le contenu source reste édité en français dans la base. Hors français,
  # on construit une description localisée à partir de la famille et des
  # notes réellement liées au produit, plutôt qu'un simple gabarit « classé
  # dans la famille ». Cela évite de dupliquer 5 contenus en base tout en
  # conservant un fallback sûr si une pyramide est incomplète.
  def translated_short_description(product)
    return product.short_description if I18n.locale == :fr

    family_name = translated_family_name(product.primary_family)
    return product.short_description if family_name.blank?

    top_notes = translated_product_notes(product, :top, limit: 2)
    base_notes = translated_product_notes(product, :base, limit: 2)
    return t("products.generated.short_description", name: product.name, family: family_name.downcase, default: product.short_description) if top_notes.blank? || base_notes.blank?

    t(
      "products.generated.short_description_with_notes",
      name: product.name,
      brand: product.brand.name,
      family: family_name.downcase,
      top_notes: translated_note_sentence(top_notes),
      base_notes: translated_note_sentence(base_notes),
      default: product.short_description
    )
  end

  def translated_description(product)
    return product.description if I18n.locale == :fr

    family_name = translated_family_name(product.primary_family)
    return product.description if family_name.blank?

    top_notes = translated_product_notes(product, :top)
    heart_notes = translated_product_notes(product, :heart)
    base_notes = translated_product_notes(product, :base)
    return t("products.generated.description", name: product.name, brand: product.brand.name, family: family_name.downcase, default: product.description) if top_notes.blank? || heart_notes.blank? || base_notes.blank?

    t(
      "products.generated.description_with_notes",
      name: product.name,
      brand: product.brand.name,
      family: family_name.downcase,
      top_notes: translated_note_sentence(top_notes),
      heart_notes: translated_note_sentence(heart_notes),
      base_notes: translated_note_sentence(base_notes),
      default: product.description
    )
  end

  # Reconstruit l'URL de la page courante dans une autre langue, en
  # remplaçant juste le préfixe de langue (ex. depuis "/en/parfums/khamrah",
  # path_in_locale(:fr) renvoie "/parfums/khamrah").
  def path_in_locale(locale)
    known_locales = I18n.available_locales.join("|")
    path_without_locale = request.path.sub(%r{\A/(#{known_locales})(?=/|\z)}, "")
    path_without_locale = "/" if path_without_locale.blank?
    locale == I18n.default_locale ? path_without_locale : "/#{locale}#{path_without_locale}"
  end

  def translated_product_notes(product, layer, limit: nil)
    notes = product.product_olfactory_notes
      .select { |link| link.layer == layer.to_s }
      .sort_by(&:position)
      .map { |link| translated_note_name(link.olfactory_note) }
      .compact_blank

    limit ? notes.first(limit) : notes
  end

  def translated_note_sentence(notes)
    return notes.first.to_s if notes.size <= 1

    connector = t("products.generated.notes_connector", default: "and")
    return notes.join(" #{connector} ") if notes.size == 2

    "#{notes.first(notes.size - 1).join(', ')} #{connector} #{notes.last}"
  end

  # Les URLs de suivi sont générées côté serveur depuis les gabarits fixes de
  # Order. Cette vérification défensive évite qu'une donnée persistée
  # inattendue puisse devenir une destination de lien dans l'admin.
  def safe_tracking_url(order)
    url = order.tracking_url
    return if url.blank?

    uri = URI.parse(url)
    return unless uri.is_a?(URI::HTTPS) && TRACKING_URL_HOSTS.include?(uri.host)

    uri.to_s
  rescue URI::InvalidURIError
    nil
  end

  def shipment_status_label(status)
    I18n.t("shipments.statuses.#{status}", default: status.to_s.humanize)
  end

  # Les URLs d’étiquette ne viennent jamais du navigateur. Elles restent
  # néanmoins validées avant rendu, afin qu’un futur connecteur transporteur
  # doive déclarer explicitement son domaine de téléchargement.
  def safe_shipment_label_url(shipment)
    return if shipment.label_url.blank?

    uri = URI.parse(shipment.label_url)
    return unless shipment.carrier == "Mondial Relay" && uri.is_a?(URI::HTTPS) && %w[api.mondialrelay.fr www.mondialrelay.fr].include?(uri.host)

    uri.to_s
  rescue URI::InvalidURIError
    nil
  end

  def safe_shipment_tracking_url(shipment)
    return if shipment.tracking_url.blank?

    uri = URI.parse(shipment.tracking_url)
    allowed = case shipment.carrier
    when "Mondial Relay"
      %w[www.mondialrelay.fr api.mondialrelay.fr]
    else
      []
    end
    allowed << "example.test" unless Rails.env.production?
    return unless uri.is_a?(URI::HTTPS) && allowed.include?(uri.host)

    uri.to_s
  rescue URI::InvalidURIError
    nil
  end

  # Les demandes vidéo sont authentifiées côté API, mais l’URL de référence
  # reste une donnée saisie par un outil externe. On ne rend donc qu’une URL
  # HTTPS absolue dans l’admin, jamais une chaîne arbitraire en href/src.
  def safe_marketing_video_reference_image_url(video_job)
    uri = URI.parse(video_job.reference_image_url.to_s)
    uri.to_s if uri.is_a?(URI::HTTPS) && uri.host.present?
  rescue URI::InvalidURIError
    nil
  end

  def safe_marketing_video_result_url(video_job)
    uri = URI.parse(video_job.result_video_url.to_s)
    uri.to_s if uri.is_a?(URI::HTTPS) && uri.host.present?
  rescue URI::InvalidURIError
    nil
  end
end

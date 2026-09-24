class SitemapsController < ApplicationController
  FAMILY_SLUGS_TO_AUDIENCE_SEGMENT = { "women" => "femme", "men" => "homme", "unisex" => "mixte" }.freeze

  # Un seul fichier couvre les 5 langues (chaque URL liste ses variantes de
  # langue via <xhtml:link hreflang>), plutôt que 5 sitemaps séparés —
  # pratique standard pour un site multilingue. N'inclut jamais /admin,
  # /panier, /commande ni aucune page privée (voir robots.txt, même liste).
  def index
    @entries = static_entries + commercial_entries + product_entries + family_entries + audience_entries
    render layout: false
  end

  private

  def static_entries
    [ root_path, products_path, quiz_path, about_path, faq_path, contact_path, shipping_path, returns_path, terms_path, privacy_path, legal_path ]
      .map { |path| { path: path } }
  end

  def product_entries
    Product.visible.order(:updated_at).map { |product| { path: product_path(product), updated_at: product.updated_at } }
  end

  def commercial_entries
    [ gourmand_perfumes_path, lattafa_perfumes_path, dubai_perfumes_path ].map { |path| { path: path } }
  end

  def family_entries
    OlfactoryFamily.active.map { |family| { path: family_catalog_path(slug: family.slug) } }
  end

  def audience_entries
    FAMILY_SLUGS_TO_AUDIENCE_SEGMENT.values.map { |segment| { path: audience_catalog_path(audience: segment) } }
  end
end

class HomeController < ApplicationController
  # Les 3 mêmes références que le hero du prototype (lib/products.ts /
  # app/page.tsx), affichées avec de vraies données Rails plutôt que du
  # texte dupliqué en dur. Si une référence venait à disparaître du
  # catalogue, sa clé est simplement absente du hash : la vue saute cet
  # emplacement au lieu de planter.
  HERO_SLUGS = { yara: "yara-lattafa", marshmallow: "kenzie-marshmallow-dream", vanilla: "vanilla-latte" }.freeze

  def index
    @featured_products = Product.featured.includes(:brand, :product_variants, product_images: { file_attachment: :blob }).limit(4)
    @hero_products = HERO_SLUGS.transform_values { |slug| Product.visible.includes(:brand, :product_variants).find_by(slug: slug) }
  end
end

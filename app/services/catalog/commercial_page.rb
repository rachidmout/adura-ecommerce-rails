module Catalog
  class CommercialPage
    AUDIENCE_SEGMENTS = { "women" => "femme", "men" => "homme", "unisex" => "mixte" }.freeze

    DEFINITIONS = {
      "gourmands" => {
        family_slugs: [ "gourmand" ],
        related_family_slugs: [ "gourmand", "fruite" ],
        related_audiences: [ "women", "unisex" ]
      },
      "lattafa" => {
        brand_slugs: [ "lattafa", "lattafa-pride" ],
        related_family_slugs: [ "gourmand", "boise", "floral" ],
        related_audiences: [ "women", "men", "unisex" ]
      },
      "dubai" => {
        # Les marques sont choisies explicitement pour cette sélection ; le
        # slug d'URL n'attribue pas une origine à chaque produit individuellement.
        brand_slugs: [ "lattafa", "lattafa-pride", "gulf-orchid", "paris-corner" ],
        related_family_slugs: [ "gourmand", "boise", "musc" ],
        related_audiences: [ "women", "men", "unisex" ]
      }
    }.freeze

    def self.find(key)
      return unless DEFINITIONS.key?(key)

      new(key)
    end

    def initialize(key)
      @key = key
    end

    attr_reader :key

    def products
      scope = Product.visible.in_stock.includes(:brand, :perfume_profile, :product_variants, product_images: { file_attachment: :blob })
      if definition[:family_slugs]
        scope = scope.joins(product_olfactory_families: :olfactory_family).where(olfactory_families: { slug: definition[:family_slugs] })
      end
      scope = scope.joins(:brand).where(brands: { slug: definition[:brand_slugs] }) if definition[:brand_slugs]
      scope.order(:name).distinct
    end

    def related_families
      OlfactoryFamily.active.where(slug: definition.fetch(:related_family_slugs)).order(:name)
    end

    def related_audiences
      definition.fetch(:related_audiences)
    end

    def related_audience_segments
      related_audiences.index_with { |audience| AUDIENCE_SEGMENTS.fetch(audience) }
    end

    private

    def definition
      DEFINITIONS.fetch(key)
    end
  end
end

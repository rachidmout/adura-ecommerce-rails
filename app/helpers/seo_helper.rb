module SeoHelper
  # Les champs saisis dans l'admin restent prioritaires. En leur absence,
  # on génère un title utile à partir de données réellement présentes sur le
  # produit (nom, marque, format, famille) plutôt qu'un title générique.
  def translated_meta_title(product)
    return product.meta_title if I18n.locale == :fr && product.meta_title.present?

    generated_product_meta_title(product)
  end

  def translated_meta_description(product)
    return product.meta_description if I18n.locale == :fr && product.meta_description.present?

    generated_product_meta_description(product)
  end

  def family_meta_title(family)
    family.meta_title.presence || family_hub_value(family, :title, "#{translated_family_name(family)} · ADURA")
  end

  def family_meta_description(family)
    family.meta_description.presence || family_hub_value(family, :meta_description, translated_family_description(family))
  end

  def family_hub_heading(family)
    family_hub_value(family, :heading, translated_family_name(family))
  end

  def family_hub_intro(family)
    family_hub_value(family, :intro, translated_family_description(family))
  end

  def family_hub_body(family)
    family_hub_value(family, :body, "")
  end

  def catalog_hub_title
    t("seo.catalog.title")
  end

  def catalog_hub_description
    t("seo.catalog.meta_description")
  end

  def catalog_hub_heading
    t("seo.catalog.heading")
  end

  def catalog_hub_intro
    t("seo.catalog.intro")
  end

  def catalog_hub_body
    t("seo.catalog.body", default: "")
  end

  def audience_hub_title(audience)
    t("seo.audiences.#{audience}.title", default: "#{translated_audience(audience)} · ADURA")
  end

  def audience_hub_description(audience)
    t("seo.audiences.#{audience}.meta_description", default: t("products.index.lead"))
  end

  def audience_hub_heading(audience)
    t("seo.audiences.#{audience}.heading", default: translated_audience(audience))
  end

  def audience_hub_intro(audience)
    t("seo.audiences.#{audience}.intro", default: t("products.index.lead"))
  end

  def audience_hub_body(audience)
    t("seo.audiences.#{audience}.body", default: "")
  end

  def product_structured_data(product)
    variants = product.product_variants.select(&:active?)
    return product_group_structured_data(product, variants) if variants.many?

    data = {
      "@context" => "https://schema.org",
      "@type" => "Product",
      "name" => product.name,
      "description" => translated_meta_description(product),
      "url" => product_url(product),
      "sku" => variants.first&.sku,
      "brand" => { "@type" => "Brand", "name" => product.brand.name },
      "image" => product_structured_image(product),
      "offers" => variants.map { |variant| offer_structured_data(product, variant) }
    }.compact

    data["aggregateRating"] = aggregate_rating_structured_data(product) if product.reviews_count.positive?
    data
  end

  def breadcrumb_structured_data(items)
    {
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" => items.each_with_index.map { |(name, url), index| { "@type" => "ListItem", "position" => index + 1, "name" => name, "item" => url } }
    }
  end

  def commercial_page_structured_data(key, products, url)
    {
      "@context" => "https://schema.org",
      "@type" => "CollectionPage",
      "name" => t("commercial_pages.#{key}.heading"),
      "description" => t("commercial_pages.#{key}.meta_description"),
      "url" => url,
      "mainEntity" => {
        "@type" => "ItemList",
        "numberOfItems" => products.size,
        "itemListElement" => products.each_with_index.map do |product, index|
          { "@type" => "ListItem", "position" => index + 1, "name" => product.name, "url" => product_url(product) }
        end
      }
    }
  end

  def organization_structured_data
    data = {
      "@context" => "https://schema.org",
      "@type" => "OnlineStore",
      "name" => "ADURA",
      "url" => root_url,
      "logo" => asset_url("brand/adura-logo-header.png"),
      "sameAs" => [ "https://www.instagram.com/adura.shop/", "https://www.tiktok.com/@adura.store" ]
    }

    return_policy = merchant_return_policy_structured_data
    data["hasMerchantReturnPolicy"] = return_policy if return_policy
    data
  end

  private

  def generated_product_meta_title(product)
    brand = product.brand&.name
    volume = seo_primary_volume(product)
    family = product.primary_family

    parts = [ product.name, brand, volume ]
    parts << translated_family_name(family) if family
    "#{parts.compact_blank.join(' ')} | ADURA"
  end

  def generated_product_meta_description(product)
    # Hors français, translated_short_description fournit déjà le texte
    # localisé/fallback prévu par l'application.
    return translated_short_description(product) unless I18n.locale == :fr

    brand = product.brand&.name
    volume = seo_primary_volume(product)
    family = product.primary_family
    family_name = translated_family_name(family) if family
    profile = product.perfume_profile
    audience = translated_audience(profile.audience) if profile&.audience.present?

    identity = [ product.name, brand, volume ].compact_blank.join(" ")
    details = [ audience, family_name ].compact_blank.join(" ").downcase
    description = "Découvrez #{identity}"
    description += ", un parfum #{details}" if details.present?
    short_description = translated_short_description(product)
    description += ". #{short_description}" if short_description.present?
    description.truncate(160, separator: " ")
  end

  def seo_primary_volume(product)
    variant = product.product_variants.select(&:active?).min_by { |item| item.position || 0 }
    return if variant.blank?

    label = variant.label.to_s.strip
    label.match?(/\A\d+\s*ml\z/i) ? label.gsub(/\s*ml\z/i, " ml") : nil
  end

  def family_hub_value(family, key, fallback)
    t("seo.families.#{family.slug}.#{key}", default: fallback)
  end

  def product_structured_image(product)
    absolute_image_url(product.primary_image)
  end

  def product_group_structured_data(product, variants)
    data = {
      "@context" => "https://schema.org",
      "@type" => "ProductGroup",
      "name" => product.name,
      "description" => translated_meta_description(product),
      "url" => product_url(product),
      "brand" => { "@type" => "Brand", "name" => product.brand.name },
      "image" => product_structured_image(product),
      "productGroupID" => "ADURA-#{product.id}",
      "variesBy" => [ "https://schema.org/size" ],
      "hasVariant" => variants.map { |variant| product_variant_structured_data(product, variant) }
    }.compact

    data["aggregateRating"] = aggregate_rating_structured_data(product) if product.reviews_count.positive?
    data
  end

  def product_variant_structured_data(product, variant)
    data = {
      "@type" => "Product",
      "name" => "#{product.name} · #{variant.label}",
      "description" => translated_meta_description(product),
      "image" => product_variant_structured_image(product, variant),
      "sku" => variant.sku,
      "size" => variant.label,
      "offers" => offer_structured_data(product, variant)
    }.compact

    data.merge!(structured_gtin(variant.gtin)) if variant.gtin.present?
    data
  end

  def product_variant_structured_image(product, variant)
    absolute_image_url(variant.gallery_images.first) || product_structured_image(product)
  end

  def absolute_image_url(image)
    return nil unless image&.file&.attached?

    rails_blob_url(image.file, host: request.base_url)
  end

  def offer_structured_data(product, variant)
    {
      "@type" => "Offer",
      "url" => product_url(product),
      "priceSpecification" => unit_price_specification(variant),
      "itemCondition" => "https://schema.org/NewCondition",
      "availability" => variant.available? ? "https://schema.org/InStock" : "https://schema.org/OutOfStock",
      "sku" => variant.sku
    }.compact
  end

  def unit_price_specification(variant)
    return if variant.price_cents.nil?

    {
      "@type" => "UnitPriceSpecification",
      "price" => format("%.2f", variant.price_cents / 100.0),
      "priceCurrency" => variant.currency,
      "referenceQuantity" => {
        "@type" => "QuantitativeValue",
        "value" => variant.volume_ml,
        "unitCode" => "ML",
        "valueReference" => {
          "@type" => "QuantitativeValue",
          "value" => 100,
          "unitCode" => "ML"
        }
      }
    }
  end

  def structured_gtin(gtin)
    digits = gtin.to_s
    return {} unless [ 8, 12, 13, 14 ].include?(digits.length)

    { "gtin#{digits.length}" => digits }
  end

  def merchant_return_policy_structured_data
    countries = ShippingZone.joins(:shipping_zone_countries)
      .where(active: true)
      .distinct
      .order("shipping_zone_countries.country_code")
      .pluck("shipping_zone_countries.country_code")
    return if countries.empty?

    {
      "@type" => "MerchantReturnPolicy",
      "applicableCountry" => countries,
      "returnPolicyCountry" => "FR",
      "merchantReturnLink" => returns_url,
      "returnPolicyCategory" => "https://schema.org/MerchantReturnFiniteReturnWindow",
      "merchantReturnDays" => 14,
      "returnMethod" => "https://schema.org/ReturnByMail",
      "returnFees" => "https://schema.org/ReturnFeesCustomerResponsibility"
    }
  end

  def aggregate_rating_structured_data(product)
    {
      "@type" => "AggregateRating",
      "ratingValue" => format("%.1f", product.average_rating),
      "reviewCount" => product.reviews_count
    }
  end
end

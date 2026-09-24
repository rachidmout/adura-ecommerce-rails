module ProductImages
  # Réattache les ProductImage à partir des fichiers sources et du service
  # Active Storage courant (config.active_storage.service), pour des
  # Product/ProductVariant déjà existants. Ne crée, ne modifie et ne supprime
  # jamais de Product, ProductVariant, prix, stock, statut, ShopSetting,
  # AdminUser, Order ou Payment — uniquement ProductImage et son attachment.
  class Reattach
    Result = Struct.new(:processed, :products_skipped, :variants_skipped, :missing_files, keyword_init: true)

    def initialize(catalog:, source_dir: Rails.root.join("app/assets/images/products"))
      @catalog = catalog
      @source_dir = Pathname.new(source_dir)
    end

    def call
      processed = 0
      products_skipped = []
      variants_skipped = []
      missing_files = []

      catalog.each do |data|
        product = Product.find_by(slug: data[:slug])
        unless product
          products_skipped << data[:slug]
          next
        end

        variants_with_images = [ { volume: data[:volume], images: data[:images] } ] +
          Array(data[:extra_variants]).map { |extra| { volume: extra[:volume], images: extra[:images] } }

        # Repart de zéro pour CE produit à chaque exécution (comme le fait déjà
        # db/seeds.rb) : que ses images soient actuellement absentes, sur
        # l'ancien service local, ou déjà sur le nouveau, le résultat final est
        # toujours le même jeu cohérent. C'est ce qui permet de relancer cette
        # tâche sans risque depuis l'état partiel actuel.
        product.product_images.destroy_all

        variants_with_images.each do |entry|
          variant = product.product_variants.find_by(volume_ml: entry[:volume])
          unless variant
            variants_skipped << "#{data[:slug]} #{entry[:volume]}ml"
            next
          end

          Array(entry[:images]).each_with_index do |filename, position|
            path = source_dir.join(filename)
            unless path.exist?
              missing_files << filename
              next
            end

            is_primary = entry == variants_with_images.first && position.zero?
            image = product.product_images.find_or_initialize_by(product_variant: variant, position: position)
            image.alt_text = "#{data[:name]} de #{data[:brand]} · #{variant.label}#{" avec coffret" if position.positive?}"
            image.primary = true if is_primary
            image.save!
            image.file.attach(io: File.open(path), filename: filename, content_type: Marcel::MimeType.for(path))
            processed += 1
          end
        end
      end

      Result.new(processed: processed, products_skipped: products_skipped, variants_skipped: variants_skipped, missing_files: missing_files)
    end

    private

    attr_reader :catalog, :source_dir
  end
end

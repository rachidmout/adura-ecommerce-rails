namespace :product_images do
  desc "Réattache les 87 ProductImage vers le service Active Storage courant (R2 en production), sans toucher Product/ProductVariant/prix/stock/statut/ShopSetting/AdminUser/Order/Payment"
  task reattach: :environment do
    catalog = ProductImages::SeedCatalog.load
    unless catalog.size == 41
      abort "catalog : #{catalog.size} produits trouvés dans db/seeds.rb, 41 attendus — arrêt par sécurité, rien n'a été modifié."
    end

    service_name = Rails.application.config.active_storage.service
    unless service_name == :r2
      abort "Service Active Storage actif = #{service_name.inspect} (pas :r2) — arrêt par sécurité, rien n'a été modifié."
    end

    puts "Service Active Storage actif : #{service_name.inspect}"
    puts "#{catalog.size} produits dans le catalogue. Réattachement en cours…"

    result = ProductImages::Reattach.new(catalog: catalog).call

    puts
    puts "Terminé : #{result.processed} images traitées."
    puts "Produits ignorés (introuvables) : #{result.products_skipped.join(', ')}" if result.products_skipped.any?
    puts "Variantes ignorées (introuvables) : #{result.variants_skipped.join(', ')}" if result.variants_skipped.any?
    puts "Fichiers source manquants : #{result.missing_files.join(', ')}" if result.missing_files.any?
    puts "ProductImage=#{ProductImage.count} Attachment=#{ActiveStorage::Attachment.count} Blob=#{ActiveStorage::Blob.count}"
    puts "Répartition service_name : #{ActiveStorage::Blob.group(:service_name).count}"
  end
end

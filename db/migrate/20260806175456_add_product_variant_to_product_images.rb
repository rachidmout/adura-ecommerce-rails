class AddProductVariantToProductImages < ActiveRecord::Migration[8.1]
  def change
    # Nullable : une image "générique" du produit (celle qui sert de vignette
    # sur les cartes catalogue/panier) n'a pas besoin d'être liée à un format
    # précis. Seules les photos de galerie propres à une variante (flacon +
    # coffret pour tel volume) renseignent cette colonne.
    add_reference :product_images, :product_variant, null: true, foreign_key: true
  end
end

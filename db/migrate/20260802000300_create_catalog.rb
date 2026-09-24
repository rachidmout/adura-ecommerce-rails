class CreateCatalog < ActiveRecord::Migration[8.1]
  def change
    create_table :brands do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :brands, :slug, unique: true
    add_index :brands, "lower(name)", unique: true, name: :index_brands_on_lower_name

    create_table :products do |t|
      t.references :brand, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.string :short_description
      t.text :description
      t.string :status, null: false, default: "draft"
      t.boolean :featured, null: false, default: false
      t.integer :featured_position
      t.text :source_urls, array: true, default: [], null: false
      t.datetime :verified_at
      t.datetime :published_at
      t.datetime :archived_at
      t.timestamps
    end
    add_index :products, :slug, unique: true
    add_index :products, %i[status featured]
    add_index :products, "lower(name)", name: :index_products_on_lower_name

    create_table :perfume_profiles do |t|
      t.references :product, null: false, foreign_key: true, index: { unique: true }
      t.string :audience, null: false
      t.string :concentration
      t.string :intensity_level
      t.string :longevity_level
      t.string :sillage_level
      t.text :season_codes, array: true, default: [], null: false
      t.text :occasion_codes, array: true, default: [], null: false
      t.text :style_codes, array: true, default: [], null: false
      t.timestamps
    end
    add_index :perfume_profiles, :audience

    create_table :product_variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :sku, null: false
      t.string :gtin
      t.integer :volume_ml, null: false
      t.integer :price_cents, null: false
      t.string :currency, null: false, default: "EUR", limit: 3
      t.integer :stock_quantity, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :product_variants, :sku, unique: true
    add_index :product_variants, :gtin, unique: true, where: "gtin IS NOT NULL"
    add_index :product_variants, %i[product_id active position]
    add_check_constraint :product_variants, "volume_ml > 0", name: :product_variants_volume_positive
    add_check_constraint :product_variants, "price_cents >= 0", name: :product_variants_price_non_negative
    add_check_constraint :product_variants, "stock_quantity >= 0", name: :product_variants_stock_non_negative

    create_table :product_images do |t|
      t.references :product, null: false, foreign_key: true
      t.string :alt_text, null: false
      t.integer :position, null: false, default: 0
      t.boolean :primary, null: false, default: false
      t.timestamps
    end
    add_index :product_images, %i[product_id position]
    add_index :product_images, :product_id, unique: true, where: '"primary" = TRUE', name: :index_product_images_one_primary
  end
end

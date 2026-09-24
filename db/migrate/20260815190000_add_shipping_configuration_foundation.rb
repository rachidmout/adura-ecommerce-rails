class AddShippingConfigurationFoundation < ActiveRecord::Migration[8.1]
  def change
    add_column :product_variants, :shipping_weight_grams, :integer
    add_check_constraint :product_variants,
                         "shipping_weight_grams IS NULL OR shipping_weight_grams > 0",
                         name: "product_variants_shipping_weight_positive"

    add_column :shop_settings, :base_packaging_weight_grams, :integer
    add_check_constraint :shop_settings,
                         "base_packaging_weight_grams IS NULL OR base_packaging_weight_grams > 0",
                         name: "shop_settings_base_packaging_weight_positive"

    create_table :shipping_zones do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: false
      t.timestamps
    end
    add_index :shipping_zones, "lower(name)", unique: true, name: "index_shipping_zones_on_lower_name"

    create_table :shipping_zone_countries do |t|
      t.references :shipping_zone, null: false, foreign_key: true
      t.string :country_code, null: false, limit: 2
      t.timestamps
    end
    add_index :shipping_zone_countries, :country_code, unique: true
    add_index :shipping_zone_countries, [ :shipping_zone_id, :country_code ], unique: true

    create_table :shipping_methods do |t|
      t.references :shipping_zone, null: false, foreign_key: true
      t.string :name, null: false
      t.string :carrier_name, null: false
      t.boolean :active, null: false, default: false
      t.integer :free_shipping_threshold_cents
      t.timestamps
    end
    add_index :shipping_methods, [ :shipping_zone_id, :name ], unique: true
    add_check_constraint :shipping_methods,
                         "free_shipping_threshold_cents IS NULL OR free_shipping_threshold_cents >= 0",
                         name: "shipping_methods_free_threshold_non_negative"

    create_table :shipping_rates do |t|
      t.references :shipping_method, null: false, foreign_key: true
      t.integer :min_weight_grams, null: false
      t.integer :max_weight_grams
      t.integer :price_cents, null: false
      t.boolean :active, null: false, default: false
      t.timestamps
    end
    add_check_constraint :shipping_rates, "min_weight_grams >= 0", name: "shipping_rates_min_weight_non_negative"
    add_check_constraint :shipping_rates,
                         "max_weight_grams IS NULL OR max_weight_grams > min_weight_grams",
                         name: "shipping_rates_max_weight_above_minimum"
    add_check_constraint :shipping_rates, "price_cents >= 0", name: "shipping_rates_price_non_negative"

    enable_extension "btree_gist" unless extension_enabled?("btree_gist")
    add_exclusion_constraint :shipping_rates,
                             "shipping_method_id WITH =, int4range(min_weight_grams, max_weight_grams + 1, '[)') WITH &&",
                             using: :gist,
                             name: "shipping_rates_weight_ranges_do_not_overlap"
  end
end

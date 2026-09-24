class CreatePromoCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :promo_codes do |t|
      t.string :code, null: false
      t.string :discount_type, null: false, default: "percentage"
      t.integer :discount_value, null: false
      t.datetime :starts_at
      t.datetime :ends_at
      t.boolean :active, null: false, default: true
      t.integer :max_uses
      t.integer :max_uses_per_customer
      t.integer :min_order_cents
      t.timestamps
    end
    add_index :promo_codes, "lower(code)", unique: true, name: :index_promo_codes_on_lower_code
    add_check_constraint :promo_codes, "discount_value > 0", name: :promo_codes_discount_value_positive
    add_check_constraint :promo_codes, "discount_type != 'percentage' OR discount_value <= 100", name: :promo_codes_percentage_within_range

    # Ciblage optionnel produits/familles : une ligne absente pour un code
    # donné signifie "valable sur tout le catalogue" (pas de champ booléen
    # séparé à garder synchronisé).
    create_table :promo_code_products do |t|
      t.references :promo_code, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.timestamps
    end
    add_index :promo_code_products, %i[promo_code_id product_id], unique: true, name: :index_promo_code_products_uniqueness

    create_table :promo_code_olfactory_families do |t|
      t.references :promo_code, null: false, foreign_key: true
      t.references :olfactory_family, null: false, foreign_key: true
      t.timestamps
    end
    add_index :promo_code_olfactory_families, %i[promo_code_id olfactory_family_id], unique: true, name: :index_promo_code_families_uniqueness
  end
end

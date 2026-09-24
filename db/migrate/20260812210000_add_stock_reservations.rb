class AddStockReservations < ActiveRecord::Migration[8.1]
  def change
    add_column :product_variants, :reserved_stock_quantity, :integer, null: false, default: 0
    add_check_constraint :product_variants, "reserved_stock_quantity >= 0", name: :product_variants_reserved_stock_non_negative
    add_check_constraint :product_variants, "reserved_stock_quantity <= stock_quantity", name: :product_variants_reserved_stock_not_above_physical

    add_column :payments, :checkout_expires_at, :datetime
    add_column :payments, :stripe_coupon_id, :string
    add_index :payments, :stripe_coupon_id, unique: true, where: "stripe_coupon_id IS NOT NULL"

    create_table :stock_reservations do |t|
      t.references :payment, null: false, foreign_key: true, index: { unique: true }
      t.string :state, null: false, default: "pending_session"
      t.datetime :expires_at, null: false
      t.datetime :activated_at
      t.datetime :consumed_at
      t.datetime :released_at
      t.timestamps
    end
    add_index :stock_reservations, %i[state expires_at]

    create_table :stock_reservation_items do |t|
      t.references :stock_reservation, null: false, foreign_key: true
      t.references :product_variant, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.timestamps
    end
    add_index :stock_reservation_items, %i[stock_reservation_id product_variant_id], unique: true, name: :index_stock_reservation_items_unique_variant
    add_check_constraint :stock_reservation_items, "quantity > 0", name: :stock_reservation_items_quantity_positive
  end
end

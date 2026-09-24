class CreateOrdersAndPayments < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.string :public_token, null: false
      t.string :status, null: false, default: "pending"
      t.string :email, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :phone, null: false
      t.string :address_line1, null: false
      t.string :address_line2
      t.string :postal_code, null: false
      t.string :city, null: false
      t.string :country_code, null: false, default: "FR", limit: 2
      t.integer :subtotal_cents, null: false
      t.integer :shipping_cents, null: false
      t.integer :total_cents, null: false
      t.string :currency, null: false, default: "EUR", limit: 3
      t.integer :shipping_rate_snapshot_cents, null: false
      t.integer :free_shipping_threshold_snapshot_cents
      t.datetime :terms_accepted_at, null: false
      t.datetime :paid_at
      t.datetime :shipped_at
      t.datetime :cancelled_at
      t.datetime :stock_decremented_at
      t.timestamps
    end
    add_index :orders, :public_token, unique: true
    add_index :orders, %i[status created_at]
    add_index :orders, "lower(email)", name: :index_orders_on_lower_email
    add_check_constraint :orders, "subtotal_cents >= 0 AND shipping_cents >= 0 AND total_cents >= 0", name: :orders_totals_non_negative
    add_check_constraint :orders, "total_cents = subtotal_cents + shipping_cents", name: :orders_total_consistent

    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :product_variant, foreign_key: true
      t.string :product_name, null: false
      t.string :brand_name, null: false
      t.string :variant_label, null: false
      t.string :sku, null: false
      t.integer :volume_ml, null: false
      t.integer :unit_price_cents, null: false
      t.integer :quantity, null: false
      t.integer :line_total_cents, null: false
      t.timestamps
    end
    add_index :order_items, %i[order_id product_variant_id]
    add_check_constraint :order_items, "quantity > 0", name: :order_items_quantity_positive
    add_check_constraint :order_items, "unit_price_cents >= 0 AND line_total_cents = unit_price_cents * quantity", name: :order_items_total_consistent

    create_table :payments do |t|
      t.references :order, null: false, foreign_key: true
      t.string :provider, null: false, default: "stripe"
      t.string :status, null: false, default: "pending"
      t.string :checkout_session_id
      t.string :payment_intent_id
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: "EUR", limit: 3
      t.text :checkout_url
      t.string :failure_code
      t.text :failure_message
      t.timestamps
    end
    add_index :payments, :checkout_session_id, unique: true, where: "checkout_session_id IS NOT NULL"
    add_index :payments, :payment_intent_id, where: "payment_intent_id IS NOT NULL"

    create_table :payment_events do |t|
      t.references :payment, foreign_key: true
      t.string :stripe_event_id, null: false
      t.string :event_type, null: false
      t.string :status, null: false, default: "received"
      t.jsonb :payload_json, null: false, default: {}
      t.datetime :processed_at
      t.text :error_message
      t.timestamps
    end
    add_index :payment_events, :stripe_event_id, unique: true
    add_index :payment_events, %i[status created_at]

    create_table :order_status_events do |t|
      t.references :order, null: false, foreign_key: true
      t.references :admin_user, foreign_key: true
      t.string :from_status
      t.string :to_status, null: false
      t.string :source, null: false
      t.text :note
      t.timestamps
    end
    add_index :order_status_events, %i[order_id created_at]
  end
end

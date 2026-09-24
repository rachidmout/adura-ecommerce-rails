class AddPickupPointsToShippingAndOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :shipping_methods, :kind, :string, default: "home_delivery", null: false
    add_check_constraint :shipping_methods, "kind IN ('home_delivery', 'pickup_point')", name: "shipping_methods_kind_valid"

    add_column :orders, :shipping_method_kind, :string

    create_table :order_relay_points do |t|
      t.references :order, null: false, foreign_key: true, index: { unique: true }
      t.string :carrier, null: false
      t.string :relay_id, null: false
      t.string :relay_name, null: false
      t.string :relay_address_line1, null: false
      t.string :relay_address_line2
      t.string :relay_postal_code, null: false
      t.string :relay_city, null: false
      t.string :relay_country, limit: 2, null: false
      t.text :relay_opening_hours
      t.jsonb :relay_raw_data, default: {}, null: false
      t.timestamps
    end

    add_index :order_relay_points, [ :carrier, :relay_id ]
  end
end

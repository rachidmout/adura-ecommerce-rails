class CreateShipments < ActiveRecord::Migration[8.1]
  def change
    create_table :shipments do |t|
      t.references :order, null: false, foreign_key: true, index: { unique: true }
      t.string :carrier, null: false
      t.string :service, null: false
      t.string :status, null: false, default: "pending"
      t.string :carrier_shipment_id
      t.string :tracking_number
      t.text :tracking_url
      t.text :label_url
      t.text :error_message
      t.jsonb :raw_response, null: false, default: {}

      t.timestamps
    end

    add_index :shipments, [ :carrier, :carrier_shipment_id ], unique: true, where: "carrier_shipment_id IS NOT NULL"
    add_check_constraint :shipments, "status IN ('pending', 'created', 'label_ready', 'failed')", name: "shipments_valid_status"
  end
end

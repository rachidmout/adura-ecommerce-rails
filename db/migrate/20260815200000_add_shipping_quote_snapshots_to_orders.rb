class AddShippingQuoteSnapshotsToOrders < ActiveRecord::Migration[8.1]
  def change
    change_table :orders, bulk: true do |t|
      t.string :shipping_zone_name
      t.string :shipping_method_name
      t.string :shipping_carrier_name
      t.integer :shipping_weight_grams
    end
  end
end

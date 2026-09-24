class AddShippingDetailsToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :shipping_carrier, :string
    add_column :orders, :tracking_number, :string
  end
end

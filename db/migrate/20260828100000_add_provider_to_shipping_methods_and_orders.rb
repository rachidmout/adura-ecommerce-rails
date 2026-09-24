class AddProviderToShippingMethodsAndOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :shipping_methods, :provider, :string, null: false, default: "direct"
    add_column :shipping_methods, :provider_carrier_code, :string
    add_column :shipping_methods, :provider_method_id_override, :string
    add_check_constraint :shipping_methods, "provider IN ('direct', 'sendcloud')", name: "shipping_methods_provider_valid"

    add_column :orders, :shipping_provider, :string
    add_column :orders, :shipping_provider_carrier_code, :string
  end
end

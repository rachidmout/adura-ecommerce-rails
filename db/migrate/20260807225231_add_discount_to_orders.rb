class AddDiscountToOrders < ActiveRecord::Migration[8.1]
  def change
    add_reference :orders, :promo_code, foreign_key: true, null: true
    add_column :orders, :discount_cents, :integer, null: false, default: 0

    remove_check_constraint :orders, name: "orders_total_consistent"
    add_check_constraint :orders, "total_cents = (subtotal_cents + shipping_cents - discount_cents)", name: "orders_total_consistent"
    remove_check_constraint :orders, name: "orders_totals_non_negative"
    add_check_constraint :orders, "subtotal_cents >= 0 AND shipping_cents >= 0 AND discount_cents >= 0 AND total_cents >= 0", name: "orders_totals_non_negative"
  end
end

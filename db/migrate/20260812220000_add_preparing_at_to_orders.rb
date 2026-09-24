class AddPreparingAtToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :preparing_at, :datetime
  end
end

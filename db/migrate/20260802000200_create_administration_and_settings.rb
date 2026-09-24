class CreateAdministrationAndSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.boolean :active, null: false, default: true
      t.datetime :last_signed_in_at
      t.timestamps
    end
    add_index :admin_users, "lower(email)", unique: true, name: :index_admin_users_on_lower_email

    create_table :shop_settings do |t|
      t.string :code, null: false, default: "default"
      t.integer :shipping_rate_cents, null: false, default: 490
      t.integer :free_shipping_threshold_cents, default: 5_000
      t.string :currency, null: false, default: "EUR", limit: 3
      t.string :shipping_country_code, null: false, default: "FR", limit: 2
      t.references :updated_by_admin_user, foreign_key: { to_table: :admin_users }
      t.timestamps
    end
    add_index :shop_settings, :code, unique: true
    add_check_constraint :shop_settings, "shipping_rate_cents >= 0", name: :shop_settings_shipping_rate_non_negative
    add_check_constraint :shop_settings, "free_shipping_threshold_cents IS NULL OR free_shipping_threshold_cents >= 0", name: :shop_settings_free_threshold_non_negative
  end
end

class CreateProductRedirects < ActiveRecord::Migration[8.1]
  def change
    create_table :product_redirects do |t|
      t.string :old_slug, null: false
      t.references :product, null: false, foreign_key: true
      t.timestamps
    end
    add_index :product_redirects, :old_slug, unique: true
  end
end

class CreateOlfactoryReferences < ActiveRecord::Migration[8.1]
  def change
    create_table :olfactory_families do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :olfactory_families, :slug, unique: true
    add_index :olfactory_families, "lower(name)", unique: true, name: :index_olfactory_families_on_lower_name

    create_table :product_olfactory_families do |t|
      t.references :product, null: false, foreign_key: true
      t.references :olfactory_family, null: false, foreign_key: true
      t.string :role, null: false, default: "secondary"
      t.timestamps
    end
    add_index :product_olfactory_families, %i[product_id olfactory_family_id], unique: true, name: :index_products_families_uniqueness
    add_index :product_olfactory_families, :product_id, unique: true, where: "role = 'primary'", name: :index_products_one_primary_family

    create_table :olfactory_notes do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :olfactory_notes, :slug, unique: true
    add_index :olfactory_notes, "lower(name)", unique: true, name: :index_olfactory_notes_on_lower_name

    create_table :product_olfactory_notes do |t|
      t.references :product, null: false, foreign_key: true
      t.references :olfactory_note, null: false, foreign_key: true
      t.string :layer, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :product_olfactory_notes, %i[product_id olfactory_note_id layer], unique: true, name: :index_product_notes_uniqueness
    add_index :product_olfactory_notes, %i[product_id layer position], name: :index_product_notes_display_order
  end
end

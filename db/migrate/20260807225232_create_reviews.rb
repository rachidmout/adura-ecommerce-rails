class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.references :product, null: false, foreign_key: true
      t.string :author_name, null: false
      t.string :author_email, null: false
      t.integer :rating, null: false
      t.text :comment, null: false
      t.string :status, null: false, default: "pending"
      t.boolean :verified_purchase, null: false, default: false
      t.timestamps
    end
    add_index :reviews, %i[product_id status]
    add_check_constraint :reviews, "rating BETWEEN 1 AND 5", name: :reviews_rating_range
  end
end

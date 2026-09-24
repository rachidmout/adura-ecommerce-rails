# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_07_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "last_signed_in_at"
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_admin_users_on_lower_email", unique: true
  end

  create_table "brands", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_brands_on_lower_name", unique: true
    t.index ["slug"], name: "index_brands_on_slug", unique: true
  end

  create_table "marketing_video_jobs", force: :cascade do |t|
    t.string "aspect_ratio", null: false
    t.text "caption"
    t.datetime "created_at", null: false
    t.integer "duration_seconds", null: false
    t.text "error_message"
    t.datetime "failed_at"
    t.datetime "generated_at"
    t.datetime "generation_started_at"
    t.jsonb "hashtags", default: [], null: false
    t.text "higgsfield_prompt", null: false
    t.text "hook"
    t.string "marketing_angle"
    t.string "objective"
    t.string "product_name", null: false
    t.string "product_slug", null: false
    t.string "provider", default: "higgsfield", null: false
    t.string "provider_job_id"
    t.datetime "queued_for_generation_at"
    t.jsonb "raw_request", default: {}, null: false
    t.jsonb "raw_response", default: {}, null: false
    t.text "reference_image_url", null: false
    t.text "result_video_url"
    t.datetime "reviewed_at"
    t.jsonb "screen_texts", default: [], null: false
    t.text "script"
    t.string "status", default: "pending_review", null: false
    t.datetime "updated_at", null: false
    t.string "watermark_position", null: false
    t.string "watermark_text", null: false
    t.text "watermarked_video_url"
    t.index ["product_slug"], name: "index_marketing_video_jobs_on_product_slug"
    t.index ["status"], name: "index_marketing_video_jobs_on_status"
    t.check_constraint "aspect_ratio::text = '9:16'::text", name: "marketing_video_jobs_vertical_only"
    t.check_constraint "duration_seconds >= 5 AND duration_seconds <= 15", name: "marketing_video_jobs_valid_duration"
    t.check_constraint "status::text = ANY (ARRAY['pending_review'::character varying, 'approved'::character varying, 'rejected'::character varying, 'queued_for_generation'::character varying, 'generating'::character varying, 'generated'::character varying, 'failed'::character varying]::text[])", name: "marketing_video_jobs_valid_status"
    t.check_constraint "watermark_position::text = 'center_lower'::text", name: "marketing_video_jobs_valid_watermark_position"
    t.check_constraint "watermark_text::text = 'ADURA.STORE'::text", name: "marketing_video_jobs_valid_watermark"
  end

  create_table "olfactory_families", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "meta_description"
    t.string "meta_title"
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_olfactory_families_on_lower_name", unique: true
    t.index ["slug"], name: "index_olfactory_families_on_slug", unique: true
  end

  create_table "olfactory_notes", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_olfactory_notes_on_lower_name", unique: true
    t.index ["slug"], name: "index_olfactory_notes_on_slug", unique: true
  end

  create_table "order_items", force: :cascade do |t|
    t.string "brand_name", null: false
    t.datetime "created_at", null: false
    t.integer "line_total_cents", null: false
    t.bigint "order_id", null: false
    t.string "product_name", null: false
    t.bigint "product_variant_id"
    t.integer "quantity", null: false
    t.string "sku", null: false
    t.integer "unit_price_cents", null: false
    t.datetime "updated_at", null: false
    t.string "variant_label", null: false
    t.integer "volume_ml", null: false
    t.index ["order_id", "product_variant_id"], name: "index_order_items_on_order_id_and_product_variant_id"
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_variant_id"], name: "index_order_items_on_product_variant_id"
    t.check_constraint "quantity > 0", name: "order_items_quantity_positive"
    t.check_constraint "unit_price_cents >= 0 AND line_total_cents = (unit_price_cents * quantity)", name: "order_items_total_consistent"
  end

  create_table "order_relay_points", force: :cascade do |t|
    t.string "carrier", null: false
    t.datetime "created_at", null: false
    t.bigint "order_id", null: false
    t.string "relay_address_line1", null: false
    t.string "relay_address_line2"
    t.string "relay_city", null: false
    t.string "relay_country", limit: 2, null: false
    t.string "relay_id", null: false
    t.string "relay_name", null: false
    t.text "relay_opening_hours"
    t.string "relay_postal_code", null: false
    t.jsonb "relay_raw_data", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["carrier", "relay_id"], name: "index_order_relay_points_on_carrier_and_relay_id"
    t.index ["order_id"], name: "index_order_relay_points_on_order_id", unique: true
  end

  create_table "order_status_events", force: :cascade do |t|
    t.bigint "admin_user_id"
    t.datetime "created_at", null: false
    t.string "from_status"
    t.text "note"
    t.bigint "order_id", null: false
    t.string "source", null: false
    t.string "to_status", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_user_id"], name: "index_order_status_events_on_admin_user_id"
    t.index ["order_id", "created_at"], name: "index_order_status_events_on_order_id_and_created_at"
    t.index ["order_id"], name: "index_order_status_events_on_order_id"
  end

  create_table "orders", force: :cascade do |t|
    t.string "address_line1", null: false
    t.string "address_line2"
    t.datetime "cancelled_at"
    t.string "city", null: false
    t.string "country_code", limit: 2, default: "FR", null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "EUR", null: false
    t.integer "discount_cents", default: 0, null: false
    t.string "email", null: false
    t.string "first_name", null: false
    t.integer "free_shipping_threshold_snapshot_cents"
    t.string "last_name", null: false
    t.datetime "paid_at"
    t.string "phone", null: false
    t.string "postal_code", null: false
    t.datetime "preparing_at"
    t.bigint "promo_code_id"
    t.string "public_token", null: false
    t.datetime "shipped_at"
    t.string "shipping_carrier"
    t.string "shipping_carrier_name"
    t.integer "shipping_cents", null: false
    t.string "shipping_method_kind"
    t.string "shipping_method_name"
    t.string "shipping_provider"
    t.string "shipping_provider_carrier_code"
    t.integer "shipping_rate_snapshot_cents", null: false
    t.integer "shipping_weight_grams"
    t.string "shipping_zone_name"
    t.string "status", default: "pending", null: false
    t.datetime "stock_decremented_at"
    t.integer "subtotal_cents", null: false
    t.datetime "terms_accepted_at", null: false
    t.integer "total_cents", null: false
    t.string "tracking_number"
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_orders_on_lower_email"
    t.index ["promo_code_id"], name: "index_orders_on_promo_code_id"
    t.index ["public_token"], name: "index_orders_on_public_token", unique: true
    t.index ["status", "created_at"], name: "index_orders_on_status_and_created_at"
    t.check_constraint "subtotal_cents >= 0 AND shipping_cents >= 0 AND discount_cents >= 0 AND total_cents >= 0", name: "orders_totals_non_negative"
    t.check_constraint "total_cents = (subtotal_cents + shipping_cents - discount_cents)", name: "orders_total_consistent"
  end

  create_table "payment_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "event_type", null: false
    t.jsonb "payload_json", default: {}, null: false
    t.bigint "payment_id"
    t.datetime "processed_at"
    t.string "status", default: "received", null: false
    t.string "stripe_event_id", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_id"], name: "index_payment_events_on_payment_id"
    t.index ["status", "created_at"], name: "index_payment_events_on_status_and_created_at"
    t.index ["stripe_event_id"], name: "index_payment_events_on_stripe_event_id", unique: true
  end

  create_table "payments", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "checkout_expires_at"
    t.string "checkout_session_id"
    t.text "checkout_url"
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "EUR", null: false
    t.string "failure_code"
    t.text "failure_message"
    t.bigint "order_id", null: false
    t.string "payment_intent_id"
    t.string "provider", default: "stripe", null: false
    t.string "status", default: "pending", null: false
    t.string "stripe_coupon_id"
    t.datetime "updated_at", null: false
    t.index ["checkout_session_id"], name: "index_payments_on_checkout_session_id", unique: true, where: "(checkout_session_id IS NOT NULL)"
    t.index ["order_id"], name: "index_payments_on_order_id"
    t.index ["payment_intent_id"], name: "index_payments_on_payment_intent_id", where: "(payment_intent_id IS NOT NULL)"
    t.index ["stripe_coupon_id"], name: "index_payments_on_stripe_coupon_id", unique: true, where: "(stripe_coupon_id IS NOT NULL)"
  end

  create_table "perfume_profiles", force: :cascade do |t|
    t.string "audience", null: false
    t.string "concentration"
    t.datetime "created_at", null: false
    t.string "intensity_level"
    t.string "longevity_level"
    t.text "occasion_codes", default: [], null: false, array: true
    t.bigint "product_id", null: false
    t.text "season_codes", default: [], null: false, array: true
    t.string "sillage_level"
    t.text "style_codes", default: [], null: false, array: true
    t.datetime "updated_at", null: false
    t.index ["audience"], name: "index_perfume_profiles_on_audience"
    t.index ["product_id"], name: "index_perfume_profiles_on_product_id", unique: true
  end

  create_table "product_images", force: :cascade do |t|
    t.string "alt_text", null: false
    t.datetime "created_at", null: false
    t.integer "position", default: 0, null: false
    t.boolean "primary", default: false, null: false
    t.bigint "product_id", null: false
    t.bigint "product_variant_id"
    t.datetime "updated_at", null: false
    t.index ["product_id", "position"], name: "index_product_images_on_product_id_and_position"
    t.index ["product_id"], name: "index_product_images_on_product_id"
    t.index ["product_id"], name: "index_product_images_one_primary", unique: true, where: "(\"primary\" = true)"
    t.index ["product_variant_id"], name: "index_product_images_on_product_variant_id"
  end

  create_table "product_olfactory_families", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "olfactory_family_id", null: false
    t.bigint "product_id", null: false
    t.string "role", default: "secondary", null: false
    t.datetime "updated_at", null: false
    t.index ["olfactory_family_id"], name: "index_product_olfactory_families_on_olfactory_family_id"
    t.index ["product_id", "olfactory_family_id"], name: "index_products_families_uniqueness", unique: true
    t.index ["product_id"], name: "index_product_olfactory_families_on_product_id"
    t.index ["product_id"], name: "index_products_one_primary_family", unique: true, where: "((role)::text = 'primary'::text)"
  end

  create_table "product_olfactory_notes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "layer", null: false
    t.bigint "olfactory_note_id", null: false
    t.integer "position", default: 0, null: false
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["olfactory_note_id"], name: "index_product_olfactory_notes_on_olfactory_note_id"
    t.index ["product_id", "layer", "position"], name: "index_product_notes_display_order"
    t.index ["product_id", "olfactory_note_id", "layer"], name: "index_product_notes_uniqueness", unique: true
    t.index ["product_id"], name: "index_product_olfactory_notes_on_product_id"
  end

  create_table "product_redirects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "old_slug", null: false
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["old_slug"], name: "index_product_redirects_on_old_slug", unique: true
    t.index ["product_id"], name: "index_product_redirects_on_product_id"
  end

  create_table "product_variants", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "EUR", null: false
    t.string "gtin"
    t.integer "position", default: 0, null: false
    t.integer "price_cents", null: false
    t.bigint "product_id", null: false
    t.integer "reserved_stock_quantity", default: 0, null: false
    t.integer "shipping_weight_grams"
    t.string "sku", null: false
    t.integer "stock_quantity", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "volume_ml", null: false
    t.index ["gtin"], name: "index_product_variants_on_gtin", unique: true, where: "(gtin IS NOT NULL)"
    t.index ["product_id", "active", "position"], name: "index_product_variants_on_product_id_and_active_and_position"
    t.index ["product_id"], name: "index_product_variants_on_product_id"
    t.index ["sku"], name: "index_product_variants_on_sku", unique: true
    t.check_constraint "price_cents >= 0", name: "product_variants_price_non_negative"
    t.check_constraint "reserved_stock_quantity <= stock_quantity", name: "product_variants_reserved_stock_not_above_physical"
    t.check_constraint "reserved_stock_quantity >= 0", name: "product_variants_reserved_stock_non_negative"
    t.check_constraint "shipping_weight_grams IS NULL OR shipping_weight_grams > 0", name: "product_variants_shipping_weight_positive"
    t.check_constraint "stock_quantity >= 0", name: "product_variants_stock_non_negative"
    t.check_constraint "volume_ml > 0", name: "product_variants_volume_positive"
  end

  create_table "products", force: :cascade do |t|
    t.datetime "archived_at"
    t.bigint "brand_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "featured", default: false, null: false
    t.integer "featured_position"
    t.string "meta_description"
    t.string "meta_title"
    t.string "name", null: false
    t.datetime "published_at"
    t.string "short_description"
    t.string "slug", null: false
    t.text "source_urls", default: [], null: false, array: true
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.index "lower((name)::text)", name: "index_products_on_lower_name"
    t.index ["brand_id"], name: "index_products_on_brand_id"
    t.index ["slug"], name: "index_products_on_slug", unique: true
    t.index ["status", "featured"], name: "index_products_on_status_and_featured"
  end

  create_table "promo_code_olfactory_families", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "olfactory_family_id", null: false
    t.bigint "promo_code_id", null: false
    t.datetime "updated_at", null: false
    t.index ["olfactory_family_id"], name: "index_promo_code_olfactory_families_on_olfactory_family_id"
    t.index ["promo_code_id", "olfactory_family_id"], name: "index_promo_code_families_uniqueness", unique: true
    t.index ["promo_code_id"], name: "index_promo_code_olfactory_families_on_promo_code_id"
  end

  create_table "promo_code_products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.bigint "promo_code_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_promo_code_products_on_product_id"
    t.index ["promo_code_id", "product_id"], name: "index_promo_code_products_uniqueness", unique: true
    t.index ["promo_code_id"], name: "index_promo_code_products_on_promo_code_id"
  end

  create_table "promo_codes", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "discount_type", default: "percentage", null: false
    t.integer "discount_value", null: false
    t.datetime "ends_at"
    t.integer "max_uses"
    t.integer "max_uses_per_customer"
    t.integer "min_order_cents"
    t.datetime "starts_at"
    t.datetime "updated_at", null: false
    t.index "lower((code)::text)", name: "index_promo_codes_on_lower_code", unique: true
    t.check_constraint "discount_type::text <> 'percentage'::text OR discount_value <= 100", name: "promo_codes_percentage_within_range"
    t.check_constraint "discount_value > 0", name: "promo_codes_discount_value_positive"
  end

  create_table "reviews", force: :cascade do |t|
    t.string "author_email", null: false
    t.string "author_name", null: false
    t.text "comment", null: false
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.integer "rating", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.boolean "verified_purchase", default: false, null: false
    t.index ["product_id", "status"], name: "index_reviews_on_product_id_and_status"
    t.index ["product_id"], name: "index_reviews_on_product_id"
    t.check_constraint "rating >= 1 AND rating <= 5", name: "reviews_rating_range"
  end

  create_table "shipments", force: :cascade do |t|
    t.string "carrier", null: false
    t.string "carrier_shipment_id"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.text "label_url"
    t.bigint "order_id", null: false
    t.jsonb "raw_response", default: {}, null: false
    t.string "service", null: false
    t.string "status", default: "pending", null: false
    t.string "tracking_number"
    t.text "tracking_url"
    t.datetime "updated_at", null: false
    t.index ["carrier", "carrier_shipment_id"], name: "index_shipments_on_carrier_and_carrier_shipment_id", unique: true, where: "(carrier_shipment_id IS NOT NULL)"
    t.index ["order_id"], name: "index_shipments_on_order_id", unique: true
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'created'::character varying, 'label_ready'::character varying, 'failed'::character varying]::text[])", name: "shipments_valid_status"
  end

  create_table "shipping_methods", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.string "carrier_name", null: false
    t.datetime "created_at", null: false
    t.integer "free_shipping_threshold_cents"
    t.string "kind", default: "home_delivery", null: false
    t.string "name", null: false
    t.string "provider", default: "direct", null: false
    t.string "provider_carrier_code"
    t.string "provider_method_id_override"
    t.bigint "shipping_zone_id", null: false
    t.datetime "updated_at", null: false
    t.index ["shipping_zone_id", "name"], name: "index_shipping_methods_on_shipping_zone_id_and_name", unique: true
    t.index ["shipping_zone_id"], name: "index_shipping_methods_on_shipping_zone_id"
    t.check_constraint "free_shipping_threshold_cents IS NULL OR free_shipping_threshold_cents >= 0", name: "shipping_methods_free_threshold_non_negative"
    t.check_constraint "kind::text = ANY (ARRAY['home_delivery'::character varying, 'pickup_point'::character varying]::text[])", name: "shipping_methods_kind_valid"
    t.check_constraint "provider::text = ANY (ARRAY['direct'::character varying, 'sendcloud'::character varying]::text[])", name: "shipping_methods_provider_valid"
  end

  create_table "shipping_rates", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.integer "max_weight_grams"
    t.integer "min_weight_grams", null: false
    t.integer "price_cents", null: false
    t.bigint "shipping_method_id", null: false
    t.datetime "updated_at", null: false
    t.index ["shipping_method_id"], name: "index_shipping_rates_on_shipping_method_id"
    t.check_constraint "max_weight_grams IS NULL OR max_weight_grams > min_weight_grams", name: "shipping_rates_max_weight_above_minimum"
    t.check_constraint "min_weight_grams >= 0", name: "shipping_rates_min_weight_non_negative"
    t.check_constraint "price_cents >= 0", name: "shipping_rates_price_non_negative"
    t.exclusion_constraint "shipping_method_id WITH =, int4range(min_weight_grams, (max_weight_grams + 1), '[)'::text) WITH &&", using: :gist, name: "shipping_rates_weight_ranges_do_not_overlap"
  end

  create_table "shipping_zone_countries", force: :cascade do |t|
    t.string "country_code", limit: 2, null: false
    t.datetime "created_at", null: false
    t.bigint "shipping_zone_id", null: false
    t.datetime "updated_at", null: false
    t.index ["country_code"], name: "index_shipping_zone_countries_on_country_code", unique: true
    t.index ["shipping_zone_id", "country_code"], name: "idx_on_shipping_zone_id_country_code_8f71882e2b", unique: true
    t.index ["shipping_zone_id"], name: "index_shipping_zone_countries_on_shipping_zone_id"
  end

  create_table "shipping_zones", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_shipping_zones_on_lower_name", unique: true
  end

  create_table "shop_settings", force: :cascade do |t|
    t.integer "base_packaging_weight_grams"
    t.string "code", default: "default", null: false
    t.datetime "created_at", null: false
    t.string "currency", limit: 3, default: "EUR", null: false
    t.integer "free_shipping_threshold_cents", default: 5000
    t.string "shipping_country_code", limit: 2, default: "FR", null: false
    t.integer "shipping_rate_cents", default: 490, null: false
    t.datetime "updated_at", null: false
    t.bigint "updated_by_admin_user_id"
    t.index ["code"], name: "index_shop_settings_on_code", unique: true
    t.index ["updated_by_admin_user_id"], name: "index_shop_settings_on_updated_by_admin_user_id"
    t.check_constraint "base_packaging_weight_grams IS NULL OR base_packaging_weight_grams > 0", name: "shop_settings_base_packaging_weight_positive"
    t.check_constraint "free_shipping_threshold_cents IS NULL OR free_shipping_threshold_cents >= 0", name: "shop_settings_free_threshold_non_negative"
    t.check_constraint "shipping_rate_cents >= 0", name: "shop_settings_shipping_rate_non_negative"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "stock_reservation_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_variant_id", null: false
    t.integer "quantity", null: false
    t.bigint "stock_reservation_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_variant_id"], name: "index_stock_reservation_items_on_product_variant_id"
    t.index ["stock_reservation_id", "product_variant_id"], name: "index_stock_reservation_items_unique_variant", unique: true
    t.index ["stock_reservation_id"], name: "index_stock_reservation_items_on_stock_reservation_id"
    t.check_constraint "quantity > 0", name: "stock_reservation_items_quantity_positive"
  end

  create_table "stock_reservations", force: :cascade do |t|
    t.datetime "activated_at"
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "payment_id", null: false
    t.datetime "released_at"
    t.string "state", default: "pending_session", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_id"], name: "index_stock_reservations_on_payment_id", unique: true
    t.index ["state", "expires_at"], name: "index_stock_reservations_on_state_and_expires_at"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "product_variants"
  add_foreign_key "order_relay_points", "orders"
  add_foreign_key "order_status_events", "admin_users"
  add_foreign_key "order_status_events", "orders"
  add_foreign_key "orders", "promo_codes"
  add_foreign_key "payment_events", "payments"
  add_foreign_key "payments", "orders"
  add_foreign_key "perfume_profiles", "products"
  add_foreign_key "product_images", "product_variants"
  add_foreign_key "product_images", "products"
  add_foreign_key "product_olfactory_families", "olfactory_families"
  add_foreign_key "product_olfactory_families", "products"
  add_foreign_key "product_olfactory_notes", "olfactory_notes"
  add_foreign_key "product_olfactory_notes", "products"
  add_foreign_key "product_redirects", "products"
  add_foreign_key "product_variants", "products"
  add_foreign_key "products", "brands"
  add_foreign_key "promo_code_olfactory_families", "olfactory_families"
  add_foreign_key "promo_code_olfactory_families", "promo_codes"
  add_foreign_key "promo_code_products", "products"
  add_foreign_key "promo_code_products", "promo_codes"
  add_foreign_key "reviews", "products"
  add_foreign_key "shipments", "orders"
  add_foreign_key "shipping_methods", "shipping_zones"
  add_foreign_key "shipping_rates", "shipping_methods"
  add_foreign_key "shipping_zone_countries", "shipping_zones"
  add_foreign_key "shop_settings", "admin_users", column: "updated_by_admin_user_id"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "stock_reservation_items", "product_variants"
  add_foreign_key "stock_reservation_items", "stock_reservations"
  add_foreign_key "stock_reservations", "payments"
end

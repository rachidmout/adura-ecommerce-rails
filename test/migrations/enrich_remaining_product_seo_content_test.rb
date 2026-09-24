require "test_helper"
require Rails.root.join("db/migrate/20260907000000_enrich_remaining_product_seo_content").to_s

class EnrichRemainingProductSeoContentTest < ActiveSupport::TestCase
  test "remaining priority editorial content is complete and stays within product SEO limits" do
    content = EnrichRemainingProductSeoContent::CONTENT

    assert_equal 31, content.size

    content.each_value do |attributes|
      assert_operator attributes.fetch(:short_description).length, :>=, 80
      assert_operator attributes.fetch(:short_description).length, :<=, 255
      assert_operator attributes.fetch(:description).length, :>=, 200
      assert_operator attributes.fetch(:meta_title).length, :<=, 70
      assert_operator attributes.fetch(:meta_description).length, :<=, 160
    end
  end
end

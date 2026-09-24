require "test_helper"
require Rails.root.join("db/migrate/20260823150000_enrich_priority_product_seo_content").to_s

class EnrichPriorityProductSeoContentTest < ActiveSupport::TestCase
  test "priority editorial content is complete and stays within product SEO limits" do
    content = EnrichPriorityProductSeoContent::CONTENT

    assert_equal 10, content.size
    content.each_value do |attributes|
      assert attributes.fetch(:short_description).present?
      assert attributes.fetch(:description).present?
      assert_operator attributes.fetch(:meta_title).length, :<=, 70
      assert_operator attributes.fetch(:meta_description).length, :<=, 160
    end
  end
end

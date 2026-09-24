require "test_helper"

class QuizControllerTest < ActionDispatch::IntegrationTest
  test "quiz has dedicated localized metadata" do
    I18n.available_locales.each do |locale|
      get quiz_path(locale: locale)

      assert_response :success
      assert_select "title", I18n.t("quiz.show.title", locale: locale)
      assert_select "meta[name='description'][content=?]", I18n.t("quiz.show.meta_description", locale: locale)
    end
  end

  test "family choices are connected to the native radio inputs and Stimulus selection controller" do
    product = create_publishable_product(slug: "quiz-family-selection", family_slug: "gourmand")

    get quiz_path(locale: nil)

    assert_response :success
    assert_select "form.quiz-question[action=?][method='post'][data-turbo='false']", quiz_results_path(locale: nil)
    analytics_root = Nokogiri::HTML(response.body).at_css(".quiz-intro[data-quiz-analytics-started-value]")
    assert_equal "perfume_finder", JSON.parse(analytics_root["data-quiz-analytics-started-value"]).fetch("quiz_name")
    assert_includes JSON.parse(analytics_root["data-quiz-analytics-family-slugs-value"]), product.primary_family.slug
    assert_select "fieldset.quiz-options[data-controller='quiz-family']"
    assert_select ".quiz-option[data-quiz-family-target='option'] input[type='radio'][name='quiz[family]'][value=?][required='required'][data-action='change->quiz-family#select quiz-analytics#familySelected'][data-quiz-family-target='input']", product.primary_family.slug
  end

  test "selected family is submitted to the existing results flow" do
    product = create_publishable_product(slug: "quiz-family-results", family_slug: "gourmand")

    post quiz_results_path(locale: nil), params: { quiz: { family: product.primary_family.slug, audience: "all", occasion: "daily", budget: "open" } }

    assert_response :success
    assert_select ".recommendation-card", text: /#{Regexp.escape(product.name)}/
  end

  test "renders the budget range values submitted to the recommendations flow" do
    get quiz_path(locale: nil)

    assert_response :success
    assert_select "select[name='quiz[budget]'][data-action='change->quiz-analytics#budgetSelected'] option[value='under_30']", text: "Jusqu’à 30 €"
    assert_select "select[name='quiz[budget]'] option[value='30_40']", text: "30–40 €"
    assert_select "select[name='quiz[budget]'] option[value='40_50']", text: "40–50 €"
    assert_select "select[name='quiz[budget]'] option[value='50_plus']", text: "50 € et plus"
    assert_select "select[name='quiz[budget]'] option[value='open']", text: "Peu importe le prix"
  end

  test "missing family is handled by the browser-required radio group without a server crash" do
    product = create_publishable_product(slug: "quiz-family-missing", family_slug: "gourmand")

    post quiz_results_path(locale: nil), params: { quiz: { audience: "all", occasion: "daily", budget: "open" } }

    assert_response :success
    assert_select ".recommendation-card", text: /#{Regexp.escape(product.name)}/
  end

  test "valid quiz results expose a controlled completion payload without visitor data" do
    product = create_publishable_product(slug: "quiz-analytics-completed", family_slug: "gourmand", price_cents: 3_500)

    post quiz_results_path(locale: nil), params: { quiz: { family: product.primary_family.slug, audience: "all", occasion: "daily", budget: "30_40" } }

    assert_response :success
    element = Nokogiri::HTML(response.body).at_css(".quiz-results[data-quiz-analytics-completed-value]")
    payload_json = element["data-quiz-analytics-completed-value"]
    payload = JSON.parse(payload_json)

    assert_equal "perfume_finder", payload.fetch("quiz_name")
    assert_equal product.primary_family.slug, payload.fetch("family")
    assert_equal "30_40", payload.fetch("budget_range")
    assert_equal 1, payload.fetch("results_count")
    assert_no_match(/email|phone|address|postal|city|occasion|audience/i, payload_json)
  end

  test "results without a selected family do not expose a completion event" do
    post quiz_results_path(locale: nil), params: { quiz: { audience: "all", occasion: "daily", budget: "open" } }

    assert_response :success
    assert_select ".quiz-results[data-quiz-analytics-completed-value]", count: 0
  end
end

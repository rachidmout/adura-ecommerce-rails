module ReviewsHelper
  STAR_PATH = "M12 2.5l2.9 6.4 6.9.7-5.2 4.8 1.5 6.9L12 17.9l-6.1 3.4 1.5-6.9L2.2 9.6l6.9-.7L12 2.5Z".freeze

  def star_rating(rating, max: 5)
    filled = rating.to_f.round
    tag.span(class: "star-rating", aria: { hidden: true }) do
      safe_join((1..max).map { |position| single_star(filled: position <= filled) })
    end
  end

  private

  def single_star(filled:)
    content_tag(:svg, viewBox: "0 0 24 24", class: class_names("star", "is-filled" => filled)) { tag.path(d: STAR_PATH) }
  end
end

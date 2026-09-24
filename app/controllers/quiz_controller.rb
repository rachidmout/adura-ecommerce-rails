class QuizController < ApplicationController
  def show
    @families = OlfactoryFamily.active
  end

  def results
    @answers = quiz_params
    @results = Recommendations::ScoreProducts.new(answers: @answers).call
    family = OlfactoryFamily.active.find_by(slug: @answers[:family])
    @analytics_quiz_completed_event = helpers.analytics_quiz_completed_event(
      family: family&.slug,
      budget: @answers[:budget],
      results_count: @results.size
    )
    render :results
  end

  private

  def quiz_params
    params.require(:quiz).permit(:family, :audience, :occasion, :budget)
  end
end

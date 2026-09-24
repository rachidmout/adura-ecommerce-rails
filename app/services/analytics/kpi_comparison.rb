module Analytics
  KpiComparison = Data.define(:current, :previous, :percent_change, :status) do
    def self.build(current:, previous:)
      return new(current, nil, nil, :not_available) if previous.nil?
      return new(current, previous, nil, current.positive? ? :new : :not_available) if previous.zero?

      percent_change = ((current - previous).fdiv(previous) * 100).round(1)
      status = percent_change.positive? ? :up : percent_change.negative? ? :down : :neutral
      new(current, previous, percent_change, status)
    end
  end
end

ARG RUBY_VERSION=3.3.5
FROM ruby:${RUBY_VERSION}-slim

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential curl git libpq-dev libvips postgresql-client && \
    rm -rf /var/lib/apt/lists/*

ENV RAILS_ENV="development" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT=""

COPY Gemfile ./
RUN bundle install

COPY . .
RUN chmod +x bin/*

EXPOSE 3000
ENTRYPOINT ["bin/docker-entrypoint"]
CMD ["bin/rails", "server", "-b", "0.0.0.0"]

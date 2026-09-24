source "https://rubygems.org"

ruby "3.3.5"

gem "rails", "~> 8.1.3", ">= 8.1.3.1"
gem "pg", "~> 1.6"
gem "puma", ">= 6.4"
gem "propshaft"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "bcrypt", "~> 3.1"
gem "stripe", "~> 19.4"
gem "image_processing", "~> 2.0"
gem "aws-sdk-s3", require: false
gem "bootsnap", require: false
gem "google-analytics-data-v1beta", require: false

gem "rexml"

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "dotenv-rails"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end

gem "ruby-vips", "~> 2.0"

gem "solid_queue", "~> 1.6"

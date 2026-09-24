require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module Adura
  class Application < Rails::Application
    config.load_defaults 8.1
    config.time_zone = "Paris"
    config.active_record.default_timezone = :utc
    config.i18n.default_locale = :fr
    config.i18n.available_locales = %i[fr en es de it nl]
    config.generators.system_tests = nil
    config.action_view.form_with_generates_remote_forms = false
    config.filter_parameters += %i[password password_confirmation token secret stripe_signature]
  end
end

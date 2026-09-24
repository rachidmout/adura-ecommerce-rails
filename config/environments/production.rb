require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }
  config.active_storage.service = :r2
  config.assume_ssl = true
  config.force_ssl = true
  config.log_tags = [ :request_id ]
  config.logger = ActiveSupport::TaggedLogging.logger($stdout)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"
  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false
  config.active_job.queue_adapter = :solid_queue
  config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST", "https://example.com").delete_prefix("https://").delete_prefix("http://") }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV["SMTP_ADDRESS"].to_s.strip,
    port: ENV.fetch("SMTP_PORT", 587),
    user_name: ENV["SMTP_USERNAME"].to_s.strip,
    password: ENV["SMTP_PASSWORD"].to_s.strip,
    authentication: :plain,
    enable_starttls_auto: true
  }
end

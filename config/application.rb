require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module JobWizard
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # ActiveJob configuration
    # Default to :async for local-only development
    # Can be overridden with JOB_WIZARD_QUEUE_ADAPTER env var
    queue_adapter = ENV.fetch('JOB_WIZARD_QUEUE_ADAPTER', 'async').downcase
    
    if queue_adapter == 'sidekiq' && defined?(Sidekiq)
      config.active_job.queue_adapter = :sidekiq
      Rails.logger.info "Using Sidekiq for ActiveJob"
    else
      config.active_job.queue_adapter = :async
      Rails.logger.info "Using async adapter for ActiveJob"
    end
  end
end

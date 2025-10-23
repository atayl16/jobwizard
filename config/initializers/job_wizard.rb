# frozen_string_literal: true

# JobWizard configuration
module JobWizard
  # Root directory for generated PDFs and application folders
  # Can be overridden with JOB_WIZARD_OUTPUT_ROOT environment variable
  OUTPUT_ROOT = Pathname.new(
    ENV.fetch('JOB_WIZARD_OUTPUT_ROOT', File.expand_path('~/Documents/JobWizard'))
  )

  # Configuration files path
  CONFIG_PATH = Rails.root.join('config/job_wizard')

  # Temporary output path for Rails to serve downloads via send_file
  TMP_OUTPUT_ROOT = Rails.root.join('tmp/outputs')
end

# Initialize Rails configuration namespace for JobWizard
unless Rails.application.config.job_wizard
  Rails.application.config.job_wizard = ActiveSupport::OrderedOptions.new
  Rails.application.config.job_wizard.ai_enabled = ENV['OPENAI_API_KEY'].present?
end

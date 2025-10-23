# frozen_string_literal: true

# OpenAI configuration for JobWizard AI-powered resume/cover letter generation
module JobWizard
  class << self
    def openai_client
      @openai_client ||= build_openai_client
    end

    private

    def build_openai_client
      return nil if ENV['OPENAI_API_KEY'].blank?

      OpenAI::Client.new(
        access_token: ENV.fetch('OPENAI_API_KEY', nil),
        request_timeout: 30,
        log_errors: Rails.env.development?
      )
    rescue StandardError => e
      Rails.logger.warn "Failed to initialize OpenAI client: #{e.message}"
      nil
    end
  end
end

# Configuration namespace
Rails.application.config.job_wizard = ActiveSupport::OrderedOptions.new

# Configuration flags
Rails.application.config.job_wizard.ai_enabled = ENV['OPENAI_API_KEY'].present?

# Default AI writer selection
ENV['AI_WRITER'] ||= ENV['OPENAI_API_KEY'].present? ? 'openai' : 'templates'

# OpenAI model configuration
Rails.application.config.job_wizard.openai_model = ENV.fetch('OPENAI_MODEL', 'gpt-4o-mini')
Rails.application.config.job_wizard.openai_temperature_resume = ENV.fetch('OPENAI_TEMP_RESUME', '0.5').to_f
Rails.application.config.job_wizard.openai_temperature_cover_letter = ENV.fetch('OPENAI_TEMP_COVER_LETTER', '0.7').to_f
Rails.application.config.job_wizard.openai_max_tokens = ENV.fetch('OPENAI_MAX_TOKENS', '800').to_i

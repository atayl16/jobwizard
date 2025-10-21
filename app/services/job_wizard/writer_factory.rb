# frozen_string_literal: true

module JobWizard
  # Factory for creating appropriate writer based on environment configuration
  class WriterFactory
    def self.build
      case ENV['AI_WRITER']&.downcase
      when 'anthropic'
        if ENV['ANTHROPIC_API_KEY'].present?
          Writers::AnthropicWriter
        else
          Rails.logger.warn 'AI_WRITER=anthropic but ANTHROPIC_API_KEY not set, falling back to templates'
          Writers::TemplatesWriter
        end
      when 'openai'
        if ENV['OPENAI_API_KEY'].present?
          Writers::OpenaiWriter
        else
          Rails.logger.warn 'AI_WRITER=openai but OPENAI_API_KEY not set, falling back to templates'
          Writers::TemplatesWriter
        end
      else
        Writers::TemplatesWriter
      end
    end
  end
end

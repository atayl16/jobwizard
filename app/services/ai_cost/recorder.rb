# frozen_string_literal: true

module AiCost
  # Records AI usage and cost to the database
  class Recorder
    def self.log!(model:, feature:, usage:, meta: {})
      # Extract token counts from usage hash (supports both string and symbol keys)
      prompt_tokens = usage['prompt_tokens'] || usage[:prompt_tokens] || 0
      completion_tokens = usage['completion_tokens'] || usage[:completion_tokens] || 0
      cached_input_tokens = usage['cached_input_tokens'] || usage[:cached_input_tokens] || 0

      # Calculate cost
      cost_cents = AiCost.estimate_cents(
        model: model,
        prompt_tokens: prompt_tokens,
        completion_tokens: completion_tokens,
        cached_input_tokens: cached_input_tokens
      )

      # Log meta if usage data is missing
      meta = meta.dup
      meta[:missing_usage] = true if prompt_tokens.zero? && completion_tokens.zero?

      # Create and return the record
      AiUsage.create!(
        model: model,
        feature: feature,
        prompt_tokens: prompt_tokens,
        completion_tokens: completion_tokens,
        cached_input_tokens: cached_input_tokens,
        cost_cents: cost_cents,
        meta: meta
      )
    rescue StandardError => e
      Rails.logger.error "Failed to record AI usage: #{e.message}"
      nil
    end
  end
end

# frozen_string_literal: true

# AI Costing Configuration
# Provides pricing tables and cost estimation for OpenAI API usage
module AiCost
  # Default pricing (as of 2024) for gpt-4o-mini in USD per 1M tokens
  DEFAULT_PRICES = {
    'gpt-4o-mini' => {
      input: 0.15,
      cached_input: 0.075,
      output: 0.60
    },
    'gpt-4' => {
      input: 30.0,
      cached_input: 15.0,
      output: 60.0
    },
    'gpt-4-turbo' => {
      input: 10.0,
      cached_input: 5.0,
      output: 30.0
    },
    'gpt-3.5-turbo' => {
      input: 0.50,
      cached_input: 0.25,
      output: 1.50
    }
  }.freeze

  # Get pricing for a model (USD per 1M tokens)
  def self.prices_for(model)
    DEFAULT_PRICES[model] || {
      input: ENV.fetch('OPENAI_PRICE_INPUT_PER_M', '0.15').to_f,
      cached_input: ENV.fetch('OPENAI_PRICE_CACHED_INPUT_PER_M', '0.075').to_f,
      output: ENV.fetch('OPENAI_PRICE_OUTPUT_PER_M', '0.60').to_f
    }
  end

  # Estimate cost in cents from token usage
  def self.estimate_cents(model:, prompt_tokens:, completion_tokens:, cached_input_tokens: 0)
    prices = prices_for(model)

    # Calculate costs for each token type
    input_cost = (prompt_tokens / 1_000_000.0) * prices[:input]
    cached_cost = (cached_input_tokens / 1_000_000.0) * prices[:cached_input]
    output_cost = (completion_tokens / 1_000_000.0) * prices[:output]

    # Convert to cents and round up (half up rounding)
    total_usd = input_cost + cached_cost + output_cost
    (total_usd * 100).round
  end
end

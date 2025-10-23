# frozen_string_literal: true

module Jd
  # Summarizes job descriptions using AI or simple heuristics
  class Summarizer
    def self.summarize(text:, job_posting_id: nil)
      new(text, job_posting_id).summarize
    end

    def initialize(text, job_posting_id = nil)
      @text = text
      @job_posting_id = job_posting_id
    end

    def summarize
      if ai_enabled?
        ai_summarize
      else
        heuristic_summarize
      end
    end

    private

    def ai_enabled?
      Rails.application.config.job_wizard.ai_enabled
    end

    def ai_summarize
      model = ENV.fetch('AI_SUMMARY_MODEL', Rails.application.config.job_wizard.openai_model)
      temperature = ENV.fetch('AI_SUMMARY_TEMP', '0.4').to_f

      system_prompt = <<~PROMPT
        You are a job description analyzer. Extract key information from the job description below.

        CRITICAL RULES:
        - Use ONLY information explicitly stated in the job description
        - Do NOT invent or infer details not present
        - Return JSON ONLY in this exact format:

        {
          "role": "Job title/role",
          "seniority": "junior|mid|senior|staff|principal",
          "team": "Team or department name (if mentioned)",
          "stack": ["list", "of", "technologies"],
          "responsibilities": ["bulleted", "key responsibilities"],
          "notes": ["any", "notable", "details"]
        }
      PROMPT

      response = client.chat(
        parameters: {
          model: model,
          messages: [
            { role: 'system', content: system_prompt },
            { role: 'user', content: @text }
          ],
          temperature: temperature,
          max_tokens: 500,
          response_format: { type: 'json_object' }
        }
      )

      # Track usage
      usage = response['usage'] || {}
      AiCost::Recorder.log!(
        model: model,
        feature: 'jd_summary',
        usage: usage,
        meta: { job_posting_id: @job_posting_id }
      )

      content = response.dig('choices', 0, 'message', 'content')
      JSON.parse(content).symbolize_keys if content
    rescue StandardError => e
      Rails.logger.warn "AI summarization failed: #{e.message}"
      heuristic_summarize
    end

    def heuristic_summarize
      {
        role: extract_role,
        seniority: extract_seniority,
        team: nil,
        stack: extract_technologies,
        responsibilities: extract_responsibilities,
        notes: []
      }
    end

    def extract_role
      # Look for common patterns
      @text.match(/^(#{%w[Senior Staff Principal Lead Junior].join('|')})?\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s+(Engineer|Developer|Architect)/)&.send(
        :[], 0
      ) || 'Developer'
    end

    def extract_seniority
      case @text
      when /senior|sr\.|sr /i
        'senior'
      when /junior|jr\.|jr /i
        'junior'
      when /staff|principal|lead/i
        'staff'
      else
        'mid'
      end
    end

    def extract_technologies
      common_tech = %w[ruby rails javascript react python java sql postgresql mysql redis docker kubernetes aws azure
                       git github]
      text_down = @text.downcase
      common_tech.select { |tech| text_down.include?(tech) }
    end

    def extract_responsibilities
      # Simple bullet extraction
      bullets = @text.scan(/[-•]\s*([^\n]{10,100})/).flatten.first(5)
      bullets.presence || ['Collaborate with team', 'Build features']
    end

    def client
      JobWizard.openai_client
    end
  end
end

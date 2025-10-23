# frozen_string_literal: true

module Jd
  # Extracts skills from job descriptions and cross-references with experience
  class SkillExtractor
    def self.extract(text:, job_posting_id: nil)
      new(text, job_posting_id).extract
    end

    def initialize(text, job_posting_id = nil)
      @text = text
      @job_posting_id = job_posting_id
      @experience_loader = JobWizard::ExperienceLoader.new
    end

    def extract
      if ai_enabled?
        ai_extract
      else
        heuristic_extract
      end
    end

    private

    def ai_enabled?
      Rails.application.config.job_wizard.ai_enabled
    end

    def ai_extract
      model = ENV.fetch('AI_SKILLS_MODEL', Rails.application.config.job_wizard.openai_model)
      temperature = ENV.fetch('AI_SKILLS_TEMP', '0.2').to_f

      system_prompt = <<~PROMPT
        You are a skill extractor. Analyze the job description and extract ONLY skills and technologies explicitly mentioned.

        CRITICAL RULES:
        - Extract ONLY skills explicitly stated in the text
        - Do NOT infer or invent skills
        - Return JSON ONLY in this exact format:

        {
          "skills": [
            {
              "name": "skill name",
              "normalized": "normalized name",
              "evidence": ["quotes", "from", "text"],
              "confidence": 0.95
            }
          ]
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
          max_tokens: 1000,
          response_format: { type: 'json_object' }
        }
      )

      # Track usage
      usage = response['usage'] || {}
      AiCost::Recorder.log!(
        model: model,
        feature: 'skills_extract',
        usage: usage,
        meta: { job_posting_id: @job_posting_id }
      )

      content = response.dig('choices', 0, 'message', 'content')
      parsed = JSON.parse(content).symbolize_keys if content

      # Cross-reference with experience
      skills = parsed[:skills] || []
      enrich_with_profile_data(skills)
    rescue StandardError => e
      Rails.logger.warn "AI skill extraction failed: #{e.message}"
      heuristic_extract
    end

    def enrich_with_profile_data(skills)
      skills.map do |skill|
        normalized = skill['normalized'].downcase.strip
        in_profile = @experience_loader.has_skill?(normalized)

        skill.merge(
          'in_profile?' => in_profile,
          'have?' => in_profile,
          'action' => in_profile ? :keep : :prompt
        )
      end
    end

    def heuristic_extract
      common_tech = %w[ruby rails javascript react python java sql postgresql mysql redis docker kubernetes aws azure
                       git github]
      text_down = @text.downcase

      found = common_tech.select { |tech| text_down.include?(tech) }

      found.map do |skill|
        normalized = skill.downcase.strip
        in_profile = @experience_loader.has_skill?(normalized)

        {
          'name' => skill,
          'normalized' => normalized,
          'evidence' => [skill],
          'confidence' => 0.8,
          'in_profile?' => in_profile,
          'have?' => in_profile,
          'action' => in_profile ? :keep : :prompt
        }
      end
    end

    def client
      JobWizard.openai_client
    end
  end
end

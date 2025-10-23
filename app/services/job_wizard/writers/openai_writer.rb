# frozen_string_literal: true

require 'openai'

module JobWizard
  module Writers
    class OpenAIWriter
      class GenerationError < StandardError; end

      attr_reader :client, :model

      def initialize(client: JobWizard.openai_client, model: nil)
        @client = client
        @model = model || Rails.application.config.job_wizard.openai_model
        raise GenerationError, 'OpenAI client not available' if @client.nil?
      end

      def cover_letter(company:, role:, jd_text:, profile:, experience:, tone: 'warm, professional, concise')
        system_prompt = build_system_prompt(type: :cover_letter, tone: tone)
        user_prompt = build_user_prompt_cover_letter(
          company: company,
          role: role,
          jd_text: jd_text,
          profile: profile,
          experience: experience
        )

        response = call_openai!(
          system: system_prompt,
          user: user_prompt,
          temperature: Rails.application.config.job_wizard.openai_temperature_cover_letter
        )

        parse_response(response, expected_keys: %w[cover_letter unverified_skills])
      rescue StandardError => e
        Rails.logger.warn "OpenAI cover letter generation failed: #{e.message}"
        { cover_letter: nil, unverified_skills: [], error: e.message }
      end

      def resume_snippets(company:, role:, jd_text:, profile:, experience:)
        system_prompt = build_system_prompt(type: :resume)
        user_prompt = build_user_prompt_resume(
          company: company,
          role: role,
          jd_text: jd_text,
          profile: profile,
          experience: experience
        )

        response = call_openai!(
          system: system_prompt,
          user: user_prompt,
          temperature: Rails.application.config.job_wizard.openai_temperature_resume
        )

        parse_response(response, expected_keys: %w[resume_snippets unverified_skills])
      rescue StandardError => e
        Rails.logger.warn "OpenAI resume generation failed: #{e.message}"
        { resume_snippets: [], unverified_skills: [], error: e.message }
      end

      private

      def call_openai!(system:, user:, temperature:)
        response = client.chat(
          parameters: {
            model: model,
            messages: [
              { role: 'system', content: system },
              { role: 'user', content: user }
            ],
            temperature: temperature,
            max_tokens: Rails.application.config.job_wizard.openai_max_tokens,
            response_format: { type: 'json_object' }
          }
        )

        content = response.dig('choices', 0, 'message', 'content')
        raise GenerationError, 'No content in OpenAI response' if content.blank?

        content
      rescue Faraday::Error, OpenAI::Error => e
        raise GenerationError, "OpenAI API error: #{e.message}"
      end

      def parse_response(json_string, expected_keys:)
        data = JSON.parse(json_string)

        # Validate expected keys are present
        missing_keys = expected_keys - data.keys
        raise GenerationError, "Missing keys in response: #{missing_keys.join(', ')}" if missing_keys.any?

        # Ensure unverified_skills is always an array
        data['unverified_skills'] = Array(data['unverified_skills'])

        data.symbolize_keys
      rescue JSON::ParserError => e
        raise GenerationError, "Failed to parse JSON response: #{e.message}"
      end

      def build_system_prompt(type:, tone: nil)
        base = <<~PROMPT
          You are a professional résumé and cover letter writer. Your task is to create #{type == :cover_letter ? 'a cover letter' : 'resume bullet points'}.

          CRITICAL RULES (NON-NEGOTIABLE):
          1. **TRUTH-ONLY**: You MUST ONLY use facts explicitly stated in the provided PROFILE and EXPERIENCE sections.
          2. **NO INVENTION**: NEVER invent skills, projects, tools, or achievements not present in the data.
          3. **UNVERIFIED SKILLS**: If the Job Description mentions skills/tools NOT in EXPERIENCE, add them to "unverified_skills" array but DO NOT include them in generated text.
          4. **SPECIFIC > GENERIC**: Use concrete examples and quantifiable achievements when data supports it.
          5. **HUMAN TONE**: Write in a #{tone || 'warm, professional, concise'} voice. Avoid buzzwords and clichés.
          6. **JSON ONLY**: Return ONLY valid JSON matching the schema below.
        PROMPT

        if type == :cover_letter
          base + <<~SCHEMA

            SCHEMA:
            {
              "cover_letter": "<string: 3-4 paragraphs of markdown/plain text>",
              "unverified_skills": ["<array of skills mentioned in JD but not in experience>"]
            }

            COVER LETTER STRUCTURE:
            - Opening: Express genuine interest, mention 1-2 relevant skills from EXPERIENCE
            - Body: Highlight 2-3 specific achievements from EXPERIENCE that align with role
            - Closing: Brief, warm statement of interest
          SCHEMA
        else
          base + <<~SCHEMA

            SCHEMA:
            {
              "resume_snippets": ["<array of 3-5 bullet points using EXPERIENCE data>"],
              "unverified_skills": ["<array of skills mentioned in JD but not in experience>"]
            }

            BULLET POINTS:
            - Start with strong action verbs
            - Include quantifiable results when data supports it
            - Tailor to job requirements using ONLY verified experience
            - Keep each bullet to 1-2 lines
          SCHEMA
        end
      end

      def build_user_prompt_cover_letter(company:, role:, jd_text:, profile:, experience:)
        <<~PROMPT
          Create a cover letter for the following position.

          COMPANY: #{company}
          ROLE: #{role}

          JOB DESCRIPTION:
          #{jd_text.strip}

          PROFILE (verified facts only):
          #{profile}

          EXPERIENCE (verified facts only):
          #{experience}

          Remember: Use ONLY facts from PROFILE and EXPERIENCE. Any skills in JD not in EXPERIENCE go to unverified_skills array.
        PROMPT
      end

      def build_user_prompt_resume(company:, role:, jd_text:, profile:, experience:)
        <<~PROMPT
          Create resume bullet points for the following position.

          COMPANY: #{company}
          ROLE: #{role}

          JOB DESCRIPTION:
          #{jd_text.strip}

          PROFILE (verified facts only):
          #{profile}

          EXPERIENCE (verified facts only):
          #{experience}

          Remember: Use ONLY facts from PROFILE and EXPERIENCE. Any skills in JD not in EXPERIENCE go to unverified_skills array.
        PROMPT
      end
    end
  end
end

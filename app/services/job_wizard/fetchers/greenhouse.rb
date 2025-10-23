# frozen_string_literal: true

require 'httparty'

module JobWizard
  module Fetchers
    # Fetches job postings from Greenhouse boards
    # Example: Greenhouse.new.fetch('airbnb')
    class Greenhouse
      include HTTParty

      base_uri 'https://boards-api.greenhouse.io/v1/boards'

      def fetch(slug)
        url = "https://boards-api.greenhouse.io/v1/boards/#{slug}/jobs?content=true"
        Rails.logger.debug { "[Greenhouse] Fetching from: #{url}" }

        response = self.class.get("/#{slug}/jobs", query: { content: 'true' })

        unless response.success?
          Rails.logger.warn "[Greenhouse] HTTP #{response.code} for #{slug}"
          return []
        end

        jobs_data = response.parsed_response['jobs'] || []
        Rails.logger.debug { "[Greenhouse] Parsed #{jobs_data.length} jobs from #{slug} (before filtering)" }

        normalized = normalize_jobs(jobs_data, slug)
        Rails.logger.debug { "[Greenhouse] Returning #{normalized.length} jobs from #{slug} (after filtering)" }
        normalized
      rescue StandardError => e
        Rails.logger.error("[Greenhouse] Fetch error for #{slug}: #{e.message}")
        Rails.logger.error(e.backtrace.first(5).join("\n")) if e.backtrace
        []
      end

      private

      def normalize_jobs(jobs_data, slug)
        # Initialize filter and ranker
        rules = JobWizard::Rules.current
        filter = JobWizard::JobFilter.new(rules.job_filters)
        ranker = JobWizard::JobRanker.new(rules.scoring, rules.ranking)
        rules_engine = JobWizard::RulesEngine.new

        jobs_data.filter_map do |job|
          title = job['title']
          description = extract_description(job)
          location = job['location']&.[]('name')

          # Create temporary job posting for rules engine check
          temp_job = OpenStruct.new(
            company: job['company_name'] || slug.titleize,
            title: title,
            description: description,
            source: 'greenhouse'
          )

          # Apply rules engine filtering
          rejected, reasons = rules_engine.should_reject?(temp_job)
          if rejected
            Rails.logger.info("Rejected job '#{title}' at #{temp_job.company}: #{reasons.join(', ')}")
            next
          end

          # Skip jobs that don't pass the filter (includes location check)
          next unless filter.keep?(title: title, description: description, location: location)

          # Calculate score for this job (including location)
          computed_score = ranker.score(title: title, description: description, location: location)

          # Skip jobs with 0 score (below threshold)
          next if computed_score.zero?

          {
            company: job['company_name'] || slug.titleize,
            title: title,
            description: description,
            location: job['location']&.[]('name'),
            remote: job['location']&.[]('name')&.downcase&.include?('remote') || false,
            posted_at: parse_date(job['updated_at']),
            url: job['absolute_url'],
            source: 'greenhouse',
            score: computed_score,
            metadata: {
              greenhouse_id: job['id'],
              departments: job['departments']&.map { |d| d['name'] }
            }
          }
        end
      end

      def extract_description(job)
        content = job['content'] || ''
        # Combine all text content
        raw_html = [content].flatten.join("\n\n").strip

        # Use our robust HTML cleaner
        JobWizard::HtmlCleaner.clean(raw_html)
      end

      def parse_date(date_string)
        return nil if date_string.blank?

        Time.zone.parse(date_string)
      rescue StandardError
        nil
      end
    end
  end
end

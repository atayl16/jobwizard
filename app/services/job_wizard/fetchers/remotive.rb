# frozen_string_literal: true

require 'httparty'
require 'ostruct'

module JobWizard
  module Fetchers
    # Fetches job postings from Remotive API
    # Example: Remotive.new.fetch
    class Remotive
      include HTTParty

      base_uri 'https://remotive.com/api/remote-jobs'

      def fetch(_slug = nil)
        url = 'https://remotive.com/api/remote-jobs?category=software-dev'
        Rails.logger.debug { "[Remotive] Fetching from: #{url}" }

        response = self.class.get('', query: { category: 'software-dev' })

        unless response.success?
          Rails.logger.warn "[Remotive] HTTP #{response.code}"
          return []
        end

        parsed = response.parsed_response || {}
        jobs_data = parsed['jobs'] || []

        Rails.logger.debug { "[Remotive] Parsed #{jobs_data.length} jobs (before filtering)" }

        normalized = normalize_jobs(jobs_data)
        Rails.logger.debug { "[Remotive] Returning #{normalized.length} jobs (after filtering)" }
        normalized
      rescue StandardError => e
        Rails.logger.error("[Remotive] Fetch error: #{e.message}")
        Rails.logger.error(e.backtrace.first(5).join("\n")) if e.backtrace
        []
      end

      private

      def normalize_jobs(jobs_data)
        # Initialize filter and ranker
        rules = JobWizard::Rules.current
        filter = JobWizard::JobFilter.new(rules.job_filters)
        ranker = JobWizard::JobRanker.new(rules.scoring, rules.ranking)
        rules_engine = JobWizard::RulesEngine.new

        jobs_data.filter_map do |job|
          title = job['title']
          company = job['company_name']
          description = extract_description(job)
          location = job['candidate_required_location'] || 'Worldwide'

          # Create temporary job posting for rules engine check
          temp_job = OpenStruct.new(
            company: company,
            title: title,
            description: description,
            source: 'remotive'
          )

          # Apply rules engine filtering
          rejected, reasons = rules_engine.should_reject?(temp_job)
          if rejected
            Rails.logger.info("Rejected job '#{title}' at #{company}: #{reasons.join(', ')}")
            next
          end

          # Skip jobs that don't pass the filter
          next unless filter.keep?(title: title, description: description, location: location)

          # Calculate score for this job
          computed_score = ranker.score(title: title, description: description, location: location)

          # Skip jobs with 0 score (below threshold)
          next if computed_score.zero?

          {
            company: company,
            title: title,
            description: description,
            location: location,
            remote: true, # Remotive is all remote
            posted_at: parse_date(job['publication_date']),
            url: job['url'],
            source: 'remotive',
            score: computed_score,
            metadata: {
              remotive_id: job['id'],
              job_type: job['job_type'],
              category: job['category'],
              salary: job['salary']
            }
          }
        end
      end

      def extract_description(job)
        description = job['description'] || ''
        # Remotive may return HTML
        JobWizard::HtmlCleaner.clean(description)
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

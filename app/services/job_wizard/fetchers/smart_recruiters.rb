# frozen_string_literal: true

require 'httparty'

module JobWizard
  module Fetchers
    # Fetches job postings from SmartRecruiters public API
    # Example: SmartRecruiters.new.fetch('Bosch')
    class SmartRecruiters
      include HTTParty

      base_uri 'https://api.smartrecruiters.com/v1/companies'

      def fetch(company_id)
        # Fetch postings with limit
        response = self.class.get("/#{company_id}/postings", query: { limit: 100 })
        return [] unless response.success?

        jobs_data = response.parsed_response['content'] || []
        normalize_jobs(jobs_data, company_id)
      rescue StandardError => e
        Rails.logger.error("SmartRecruiters fetch error for #{company_id}: #{e.message}")
        []
      end

      private

      def normalize_jobs(jobs_data, company_id)
        # Initialize filter and ranker
        rules = JobWizard::Rules.current
        filter = JobWizard::JobFilter.new(rules.job_filters)
        ranker = JobWizard::JobRanker.new(rules.scoring, rules.ranking)
        rules_engine = JobWizard::RulesEngine.new

        jobs_data.filter_map do |job|
          title = job['name']
          description = extract_description(job)
          location = extract_location(job)

          # Create temporary job posting for rules engine check
          temp_job = OpenStruct.new(
            company: job.dig('company', 'name') || company_id,
            title: title,
            description: description,
            source: 'smartrecruiters'
          )

          # Apply rules engine filtering
          rejected, reasons = rules_engine.should_reject?(temp_job)
          if rejected
            Rails.logger.info("Rejected job '#{title}' at #{temp_job.company}: #{reasons.join(', ')}")
            next
          end

          # Skip jobs that don't pass the filter
          next unless filter.keep?(title: title, description: description, location: location)

          # Calculate score
          computed_score = ranker.score(title: title, description: description, location: location)
          next if computed_score.zero?

          {
            company: job.dig('company', 'name') || company_id,
            title: title,
            description: description,
            location: location,
            remote: check_remote(job),
            posted_at: parse_date(job['releasedDate']),
            url: "https://jobs.smartrecruiters.com/#{company_id}/#{job['id']}",
            source: 'smartrecruiters',
            score: computed_score,
            metadata: {
              smartrecruiters_id: job['id'],
              job_ad_id: job['jobAdId'],
              department: job.dig('department', 'label')
            }
          }
        end
      end

      def extract_description(job)
        # SmartRecruiters often has HTML in job description
        description = job['jobAd']&.dig('sections', 'jobDescription', 'text') || ''
        JobWizard::HtmlCleaner.clean(description)
      end

      def extract_location(job)
        location_parts = [
          job.dig('location', 'city'),
          job.dig('location', 'region'),
          job.dig('location', 'country')
        ].compact_blank

        location_parts.any? ? location_parts.join(', ') : 'Not specified'
      end

      def check_remote(job)
        remote_types = job.dig('location', 'remote') || false
        remote_types == true || extract_location(job).downcase.include?('remote')
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

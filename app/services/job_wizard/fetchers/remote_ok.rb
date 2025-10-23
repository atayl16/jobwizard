# frozen_string_literal: true

require 'httparty'
require 'ostruct'

module JobWizard
  module Fetchers
    # Fetches job postings from RemoteOK API
    # Example: RemoteOK.new.fetch
    class RemoteOk
      include HTTParty

      base_uri 'https://remoteok.com/api'

      def fetch(_slug = nil)
        url = 'https://remoteok.com/api'
        Rails.logger.debug { "[RemoteOK] Fetching from: #{url}" }

        response = self.class.get('/', headers: { 'User-Agent' => 'JobWizard/1.0' })

        unless response.success?
          Rails.logger.warn "[RemoteOK] HTTP #{response.code}"
          return []
        end

        jobs_data = response.parsed_response || []
        # RemoteOK returns array with first element being metadata, skip it
        jobs_data = jobs_data.drop(1) if jobs_data.first.is_a?(Hash) && jobs_data.first['legal']

        Rails.logger.debug { "[RemoteOK] Parsed #{jobs_data.length} jobs (before filtering)" }

        normalized = normalize_jobs(jobs_data)
        Rails.logger.debug { "[RemoteOK] Returning #{normalized.length} jobs (after filtering)" }
        normalized
      rescue StandardError => e
        Rails.logger.error("[RemoteOK] Fetch error: #{e.message}")
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
          # Filter to software/dev roles
          tags = job['tags'] || []
          next unless tags.any? do |tag|
            tag.match?(/dev|engineer|software|programmer|backend|frontend|fullstack|rails|ruby/i)
          end

          title = job['position']
          company = job['company']
          description = extract_description(job)
          location = job['location'] || 'Remote'

          # Create temporary job posting for rules engine check
          temp_job = OpenStruct.new(
            company: company,
            title: title,
            description: description,
            source: 'remoteok'
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
            remote: true, # RemoteOK is all remote
            posted_at: parse_date(job['date']),
            url: job['url'] || "https://remoteok.com/remote-jobs/#{job['id']}",
            source: 'remoteok',
            score: computed_score,
            metadata: {
              remoteok_id: job['id'],
              tags: tags,
              salary_min: job['salary_min'],
              salary_max: job['salary_max']
            }
          }
        end
      end

      def extract_description(job)
        description = job['description'] || ''
        # RemoteOK returns plain text, but may have some HTML
        JobWizard::HtmlCleaner.clean(description)
      end

      def parse_date(date_string)
        return nil if date_string.blank?

        # RemoteOK uses Unix timestamps or ISO8601
        if date_string.is_a?(Numeric) || date_string.match?(/^\d+$/)
          Time.zone.at(date_string.to_i)
        else
          Time.zone.parse(date_string)
        end
      rescue StandardError
        nil
      end
    end
  end
end

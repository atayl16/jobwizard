# frozen_string_literal: true

require 'httparty'

module JobWizard
  module Fetchers
    # Fetches job postings from Lever boards
    # Example: Lever.new.fetch('netflix')
    class Lever
      include HTTParty

      base_uri 'https://api.lever.co/v0/postings'

      def fetch(slug)
        url = "https://api.lever.co/v0/postings/#{slug}?mode=json"
        Rails.logger.debug "[Lever] Fetching from: #{url}"
        
        response = self.class.get("/#{slug}", query: { mode: 'json' })
        
        unless response.success?
          Rails.logger.warn "[Lever] HTTP #{response.code} for #{slug}"
          return []
        end

        jobs_data = response.parsed_response || []
        jobs_data = [jobs_data] unless jobs_data.is_a?(Array)
        Rails.logger.debug "[Lever] Parsed #{jobs_data.length} jobs from #{slug} (before filtering)"
        
        normalized = normalize_jobs(jobs_data, slug)
        Rails.logger.debug "[Lever] Returning #{normalized.length} jobs from #{slug} (after filtering)"
        normalized
      rescue StandardError => e
        Rails.logger.error("[Lever] Fetch error for #{slug}: #{e.message}")
        Rails.logger.error(e.backtrace.first(5).join("\n")) if e.backtrace
        []
      end

      private

      def normalize_jobs(jobs_data, slug)
        # Initialize filter and ranker
        rules = JobWizard::Rules.current
        filter = JobWizard::JobFilter.new(rules.job_filters)
        ranker = JobWizard::JobRanker.new(rules.scoring, rules.ranking)

        jobs_data.filter_map do |job|
          title = job['text']
          description = extract_description(job)
          location = extract_location(job)

          # Skip jobs that don't pass the filter (includes location check)
          next unless filter.keep?(title: title, description: description, location: location)

          # Calculate score for this job (including location)
          computed_score = ranker.score(title: title, description: description, location: location)

          # Skip jobs with 0 score (below threshold)
          next if computed_score.zero?

          {
            company: job['companyName'] || slug.titleize,
            title: title,
            description: description,
            location: extract_location(job),
            remote: check_remote(job),
            posted_at: parse_date(job['createdAt']),
            url: job['hostedUrl'] || job['applyUrl'],
            source: 'lever',
            score: computed_score,
            metadata: {
              lever_id: job['id'],
              categories: job['categories'],
              team: job.dig('categories', 'team')
            }
          }
        end
      end

      def extract_description(job)
        description = job['description'] || job['descriptionPlain'] || ''
        additional = job['additional'] || job['additionalPlain'] || ''
        raw_html = [description, additional].compact_blank.join("\n\n")

        # Use our robust HTML cleaner
        JobWizard::HtmlCleaner.clean(raw_html)
      end

      def extract_location(job)
        job.dig('categories', 'location') || job['location'] || 'Not specified'
      end

      def check_remote(job)
        location = extract_location(job).downcase
        location.include?('remote') || location.include?('anywhere')
      end

      def parse_date(timestamp)
        return nil if timestamp.nil?

        Time.zone.at(timestamp / 1000.0) # Lever uses milliseconds
      rescue StandardError
        nil
      end
    end
  end
end

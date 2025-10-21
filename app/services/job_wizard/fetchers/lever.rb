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
        response = self.class.get("/#{slug}", query: { mode: 'json' })
        return [] unless response.success?

        jobs_data = response.parsed_response
        normalize_jobs(jobs_data, slug)
      rescue => e
        Rails.logger.error("Lever fetch error for #{slug}: #{e.message}")
        []
      end

      private

      def normalize_jobs(jobs_data, slug)
        jobs_data = [jobs_data] unless jobs_data.is_a?(Array)
        
        # Initialize filter and ranker
        rules = JobWizard::Rules.current
        filter = JobWizard::JobFilter.new(rules.job_filters)
        ranker = JobWizard::JobRanker.new(rules.scoring, rules.ranking)
        
        jobs_data.filter_map do |job|
          title = job['text']
          description = extract_description(job)
          
          # Skip jobs that don't pass the filter
          next unless filter.keep?(title: title, description: description)
          
          # Calculate score for this job
          computed_score = ranker.score(title: title, description: description)
          
          # Skip jobs with 0 score (below threshold)
          next if computed_score.zero?

          {
            company: job.dig('companyName') || slug.titleize,
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
        raw_html = [description, additional].reject(&:blank?).join("\n\n")
        
        # Decode HTML entities (e.g., &lt; becomes <, &quot; becomes ")
        decoded = CGI.unescapeHTML(raw_html)
        
        # Strip all HTML tags to get clean text
        clean = ActionView::Base.full_sanitizer.sanitize(decoded)
        
        # Decode any remaining HTML entities (e.g., &amp; becomes &)
        CGI.unescapeHTML(clean).strip
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
        Time.at(timestamp / 1000.0) # Lever uses milliseconds
      rescue
        nil
      end
    end
  end
end


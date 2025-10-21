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
        response = self.class.get("/#{slug}/jobs", query: { content: 'true' })
        return [] unless response.success?

        jobs_data = response.parsed_response['jobs'] || []
        normalize_jobs(jobs_data, slug)
      rescue => e
        Rails.logger.error("Greenhouse fetch error for #{slug}: #{e.message}")
        []
      end

      private

      def normalize_jobs(jobs_data, slug)
        jobs_data.map do |job|
          {
            company: job.dig('company_name') || slug.titleize,
            title: job['title'],
            description: extract_description(job),
            location: job['location']&.[]('name'),
            remote: job['location']&.[]('name')&.downcase&.include?('remote') || false,
            posted_at: parse_date(job['updated_at']),
            url: job['absolute_url'],
            source: 'greenhouse',
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
        
        # Decode HTML entities (e.g., &lt; becomes <, &quot; becomes ")
        decoded = CGI.unescapeHTML(raw_html)
        
        # Strip all HTML tags to get clean text
        clean = ActionView::Base.full_sanitizer.sanitize(decoded)
        
        # Decode any remaining HTML entities (e.g., &amp; becomes &)
        CGI.unescapeHTML(clean).strip
      end

      def parse_date(date_string)
        return nil if date_string.blank?
        Time.parse(date_string)
      rescue
        nil
      end
    end
  end
end


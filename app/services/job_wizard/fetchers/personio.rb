# frozen_string_literal: true

require 'httparty'
require 'nokogiri'

module JobWizard
  module Fetchers
    # Fetches job postings from Personio XML feeds
    # Example: Personio.new.fetch('demodesk') -> fetches from demodesk.jobs.personio.de/xml
    class Personio
      include HTTParty

      def fetch(company_slug)
        url = "https://#{company_slug}.jobs.personio.de/xml"
        response = self.class.get(url)
        return [] unless response.success?

        parse_xml(response.body, company_slug)
      rescue StandardError => e
        Rails.logger.error("Personio fetch error for #{company_slug}: #{e.message}")
        []
      end

      private

      def parse_xml(xml_body, company_slug)
        doc = Nokogiri::XML(xml_body)
        jobs = doc.xpath('//position')

        # Initialize filter and ranker
        rules = JobWizard::Rules.current
        filter = JobWizard::JobFilter.new(rules.job_filters)
        ranker = JobWizard::JobRanker.new(rules.scoring, rules.ranking)
        rules_engine = JobWizard::RulesEngine.new

        jobs.filter_map do |job_node|
          title = job_node.at_xpath('name')&.text
          description = extract_description(job_node)
          location = extract_location(job_node)
          company_name = job_node.at_xpath('company')&.text || company_slug.titleize

          # Create temporary job posting for rules engine check
          temp_job = OpenStruct.new(
            company: company_name,
            title: title,
            description: description,
            source: 'personio'
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
            company: company_name,
            title: title,
            description: description,
            location: location,
            remote: check_remote(location),
            posted_at: parse_date(job_node.at_xpath('createdAt')&.text),
            url: job_node.at_xpath('url')&.text,
            source: 'personio',
            score: computed_score,
            metadata: {
              personio_id: job_node.at_xpath('id')&.text,
              department: job_node.at_xpath('department')&.text,
              employment_type: job_node.at_xpath('employmentType')&.text
            }
          }
        end
      end

      def extract_description(job_node)
        # Try multiple description fields
        description = job_node.at_xpath('jobDescriptions/jobDescription')&.text ||
                      job_node.at_xpath('description')&.text ||
                      ''

        JobWizard::HtmlCleaner.clean(description)
      end

      def extract_location(job_node)
        office = job_node.at_xpath('office')&.text
        return office if office.present?

        # Fallback to city/country
        parts = [
          job_node.at_xpath('city')&.text,
          job_node.at_xpath('country')&.text
        ].compact_blank

        parts.any? ? parts.join(', ') : 'Not specified'
      end

      def check_remote(location)
        location&.downcase&.include?('remote') || false
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

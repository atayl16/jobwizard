# frozen_string_literal: true

class FetchJobsJob < ApplicationJob
  queue_as :default

  def perform
    # Use the unified fetch service
    results = JobWizard::JobFetchService.fetch_all

    if results[:total].zero?
      Rails.logger.info 'FetchJobsJob: No new jobs fetched'
    else
      Rails.logger.info "FetchJobsJob: Fetched #{results[:total]} total jobs"
      results[:by_provider].each do |provider, count|
        Rails.logger.info "  #{provider}: #{count} jobs"
      end
    end

    results[:errors].each do |error|
      Rails.logger.error "  #{error}"
    end
  end
end

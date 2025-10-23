# frozen_string_literal: true

# Optional dev-only scheduler for background job fetching
# Only enabled if Rails.env.development? and JOB_WIZARD_SCHEDULE_FETCH is set
if Rails.env.development? && ENV['JOB_WIZARD_SCHEDULE_FETCH'].present?
  require 'rufus-scheduler'

  scheduler = Rufus::Scheduler.new

  # Parse schedule (e.g., "10m" for every 10 minutes)
  schedule = ENV['JOB_WIZARD_SCHEDULE_FETCH']

  Rails.logger.info "Starting dev scheduler with interval: #{schedule}"

  scheduler.every schedule do
    begin
      Rails.logger.info "[Scheduler] Fetching jobs..."
      JobWizard::JobFetchService.fetch_all
      Rails.logger.info "[Scheduler] Job fetch complete"
    rescue StandardError => e
      Rails.logger.error "[Scheduler] Error fetching jobs: #{e.message}"
    end
  end

  # Keep scheduler running
  scheduler.join
end


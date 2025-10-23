# frozen_string_literal: true

module JobWizard
  # Unified service for fetching jobs from all configured sources
  class JobFetchService
    def self.fetch_all
      new.fetch_all
    end

    def fetch_all
      sources = SourceLoader.active_sources

      if sources.empty?
        Rails.logger.warn 'No active job sources found in sources.yml'
        return { total: 0, added: 0, updated: 0, skipped_by_status: 0, skipped_by_blocklist: 0, duplicates: 0,
                 by_provider: {}, by_source: {}, errors: [] }
      end

      results = {
        total: 0,
        added: 0,
        updated: 0,
        skipped_by_status: 0,
        skipped_by_blocklist: 0,
        duplicates: 0,
        by_provider: Hash.new(0),
        by_source: {},
        errors: []
      }

      sources.each do |source|
        fetcher = fetcher_for(source.provider)
        unless fetcher
          results[:errors] << "Unknown provider: #{source.provider} for #{source.name}"
          next
        end

        Rails.logger.info "[JobFetchService] Fetching from #{source.name} (#{source.provider})"
        jobs_data = fetcher.fetch(source.slug)

        source_stats = persist_jobs(jobs_data)

        results[:added] += source_stats[:created]
        results[:updated] += source_stats[:updated]
        results[:skipped_by_status] += source_stats[:skipped]
        results[:duplicates] += source_stats[:duplicates]
        results[:total] += source_stats[:created] + source_stats[:updated]
        results[:by_provider][source.provider] += source_stats[:created] + source_stats[:updated]
        results[:by_source][source.name] = source_stats

        Rails.logger.info "[JobFetchService] #{source.name}: #{source_stats[:created]} added, #{source_stats[:updated]} updated, #{source_stats[:skipped]} skipped (status), #{source_stats[:duplicates]} duplicates"
      rescue StandardError => e
        error_msg = "Error fetching from #{source.name} (#{source.provider}): #{e.message}"
        Rails.logger.error error_msg
        results[:errors] << error_msg
      end

      results
    end

    private

    def fetcher_for(provider)
      case provider
      when 'greenhouse'
        Fetchers::Greenhouse.new
      when 'lever'
        Fetchers::Lever.new
      when 'smartrecruiters'
        Fetchers::SmartRecruiters.new
      when 'personio'
        Fetchers::Personio.new
      when 'remoteok'
        Fetchers::RemoteOk.new
      when 'remotive'
        Fetchers::Remotive.new
      end
    end

    def persist_jobs(jobs_data)
      created_count = 0
      updated_count = 0
      skipped_count = 0
      duplicate_count = 0

      jobs_data.each do |job_data|
        # Extract external_id from metadata
        external_id = extract_external_id(job_data)

        # Find by external_id if available, otherwise by URL
        job = if external_id
                JobPosting.find_or_initialize_by(source: job_data[:source], external_id: external_id)
              else
                JobPosting.find_or_initialize_by(url: job_data[:url])
              end

        if job.new_record?
          # New job: set all attributes including status 'suggested'
          job.assign_attributes(job_data.merge(
                                  external_id: external_id,
                                  last_seen_at: Time.current,
                                  status: 'suggested'
                                ))
          job.save!
          created_count += 1
        elsif job.status.in?(%w[applied ignored exported])
          # Existing job with manual status: only update last_seen_at and metadata
          job.update!(
            last_seen_at: Time.current,
            posted_at: job_data[:posted_at] || job.posted_at,
            metadata: job_data[:metadata] || job.metadata
          )
          skipped_count += 1
        elsif job.persisted? && job.last_seen_at && job.last_seen_at > 1.hour.ago
          # Existing job in suggested status: update data
          # Check if this is truly an update or just a duplicate fetch
          duplicate_count += 1
        else
          job.assign_attributes(job_data.merge(
                                  external_id: external_id,
                                  last_seen_at: Time.current
                                ))
          job.save!
          updated_count += 1
        end
      end

      {
        created: created_count,
        updated: updated_count,
        skipped: skipped_count,
        duplicates: duplicate_count
      }
    end

    def extract_external_id(job_data)
      metadata = job_data[:metadata] || {}
      metadata[:greenhouse_id] ||
        metadata[:lever_id] ||
        metadata[:smartrecruiters_id] ||
        metadata[:personio_id] ||
        metadata[:remoteok_id] ||
        metadata[:remotive_id]
    end
  end
end

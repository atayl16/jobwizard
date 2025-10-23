# frozen_string_literal: true

namespace :jobs do
  desc 'Debug sample: fetch 3-5 jobs from each provider (no DB writes)'
  task debug_sample: :environment do
    puts '🔍 Fetching sample jobs from each provider (no DB writes)...'
    puts '=' * 80
    
    providers = {
      'greenhouse' => { fetcher: JobWizard::Fetchers::Greenhouse.new, slug: 'gitlab' },
      'lever' => { fetcher: JobWizard::Fetchers::Lever.new, slug: 'Netflix' },
      'remoteok' => { fetcher: JobWizard::Fetchers::RemoteOk.new, slug: nil },
      'remotive' => { fetcher: JobWizard::Fetchers::Remotive.new, slug: nil }
    }
    
    providers.each do |name, config|
      puts "\n📦 #{name.upcase}"
      puts '-' * 80
      
      begin
        jobs = config[:fetcher].fetch(config[:slug])
        sample = jobs.take(3)
        
        if sample.empty?
          puts "  ⚠️  No jobs returned (may be filtered out or API error)"
        else
          sample.each_with_index do |job, i|
            puts "\n  Job ##{i + 1}:"
            puts "    Company: #{job[:company]}"
            puts "    Title: #{job[:title]}"
            puts "    Location: #{job[:location]}"
            puts "    Remote: #{job[:remote]}"
            puts "    Posted: #{job[:posted_at] || 'N/A'}"
            puts "    URL: #{job[:url]}"
            puts "    Source: #{job[:source]}"
            puts "    Score: #{job[:score]}"
            puts "    External ID: #{job[:metadata]&.values&.first || 'N/A'}"
            puts "    Description (first 100 chars): #{job[:description]&.first(100)}..."
          end
          puts "\n  Total fetched: #{jobs.length} (showing #{sample.length})"
        end
      rescue StandardError => e
        puts "  ✗ Error: #{e.message}"
        puts "    #{e.backtrace.first(2).join("\n    ")}"
      end
    end
    
    puts "\n" + '=' * 80
    puts "✅ Debug sample complete. No database writes performed."
  end

  desc 'Fetch jobs from all active sources in sources.yml'
  task fetch_all: :environment do
    puts '🔍 Fetching from all active sources...'
    puts ''
    
    results = JobWizard::JobFetchService.fetch_all
    
    if results[:total].zero?
      puts '⚠️  No jobs fetched'
      puts '   Check sources.yml or try enabling more sources'
    else
      puts "✅ Total jobs: #{results[:total]}"
      puts "   • Added: #{results[:added]}"
      puts "   • Updated: #{results[:updated]}"
      puts "   • Skipped (by status): #{results[:skipped_by_status]}"
      puts "   • Duplicates: #{results[:duplicates]}"
      puts ''
      puts 'By provider:'
      results[:by_provider].each do |provider, count|
        puts "  #{provider.titleize}: #{count}"
      end
      
      if results[:by_source].any?
        puts ''
        puts 'By source:'
        results[:by_source].each do |name, stats|
          puts "  #{name}: #{stats[:created]} added, #{stats[:updated]} updated, #{stats[:skipped]} skipped, #{stats[:duplicates]} dupes"
        end
      end
    end
    
    if results[:errors].any?
      puts ''
      puts '⚠️  Errors:'
      results[:errors].each do |error|
        puts "  #{error}"
      end
    end
    
    puts ''
    puts '📊 Current database counts:'
    JobPosting.group(:source).count.each do |source, count|
      puts "   #{source.titleize}: #{count} jobs"
    end
    puts ''
    puts 'Visit /jobs to view the job board'
  end

  desc 'Fetch jobs from a specific provider (greenhouse or lever) and slug'
  task :fetch, %i[provider slug] => :environment do |_t, args|
    unless args[:provider] && args[:slug]
      puts 'Usage: rake jobs:fetch[provider,slug]'
      puts 'Example: rake jobs:fetch[greenhouse,airbnb]'
      exit 1
    end

    provider = args[:provider].downcase
    slug = args[:slug]

    # Find or create job source
    source = JobSource.find_or_create_by(provider: provider, slug: slug) do |s|
      s.name = slug.titleize
      s.active = true
    end

    puts "Fetching jobs from #{provider}/#{slug}..."

    # Fetch jobs using appropriate fetcher
    fetcher_class = case provider
                    when 'greenhouse'
                      JobWizard::Fetchers::Greenhouse.new
                    when 'lever'
                      JobWizard::Fetchers::Lever.new
                    else
                      puts "Unknown provider: #{provider}. Must be 'greenhouse' or 'lever'"
                      exit 1
                    end

    jobs_data = fetcher_class.fetch(slug)

    if jobs_data.empty?
      puts "No jobs found or error fetching from #{provider}/#{slug}"
      exit 1
    end

    # Create or update job postings
    created_count = 0
    updated_count = 0
    skipped_count = 0

    jobs_data.each do |job_data|
      # Extract external_id from metadata
      external_id = job_data[:metadata]&.dig(:greenhouse_id) || job_data[:metadata]&.dig(:lever_id)

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
        # Existing job with manual status: only update last_seen_at
        job.update!(last_seen_at: Time.current)
        skipped_count += 1
      else
        # Existing job in suggested status: update data
        job.assign_attributes(job_data.merge(
                                external_id: external_id,
                                last_seen_at: Time.current
                              ))
        job.save!
        updated_count += 1
      end
    end

    # Update source last_fetched_at
    source.mark_as_fetched!

    puts "✓ Fetched #{jobs_data.length} jobs"
    puts "  Created: #{created_count}"
    puts "  Updated: #{updated_count}"
    puts "  Skipped (manual status): #{skipped_count}" if skipped_count.positive?
  end

  desc 'Fetch from all active job sources and optionally generate PDFs'
  task :board, [:generate_pdfs] => :environment do |_t, args|
    generate_pdfs = args[:generate_pdfs] == 'true'

    sources = JobSource.active

    if sources.empty?
      puts 'No active job sources found.'
      puts 'Add sources with: rake jobs:fetch[provider,slug]'
      exit 0
    end

    puts "Fetching from #{sources.count} active source(s)...\n\n"

    total_fetched = 0
    total_generated = 0
    scanner = JobWizard::RulesScanner.new

    sources.each do |source|
      puts "→ #{source.name} (#{source.provider})"

      fetcher_class = case source.provider
                      when 'greenhouse'
                        JobWizard::Fetchers::Greenhouse.new
                      when 'lever'
                        JobWizard::Fetchers::Lever.new
                      else
                        puts "  ✗ Unknown provider: #{source.provider}"
                        next
                      end

      begin
        jobs_data = fetcher_class.fetch(source.slug)

        jobs_data.each do |job_data|
          job = JobPosting.find_or_initialize_by(url: job_data[:url])
          job.assign_attributes(job_data) if job.new_record?
          job.save!
          total_fetched += 1

          # Scan for issues
          scan_result = scanner.scan(job.description)
          has_blocking = scan_result[:blocking].any?
          has_warnings = scan_result[:warnings].any?

          flag_display = []
          flag_display << '🚫' if has_blocking
          flag_display << '⚠️' if has_warnings

          puts "  • #{job.title} #{flag_display.join(' ')}"

          # Generate PDFs if requested and no blocking flags
          if generate_pdfs && !has_blocking
            GeneratePdfsJob.perform_later(job.id)
            total_generated += 1
          end
        end

        source.mark_as_fetched!
        puts "  ✓ Fetched #{jobs_data.length} jobs\n\n"
      rescue StandardError => e
        puts "  ✗ Error: #{e.message}\n\n"
      end
    end

    puts '=' * 50
    puts "Total jobs fetched: #{total_fetched}"
    puts "PDFs queued for generation: #{total_generated}" if generate_pdfs

    # Clean up jobs that no longer match current criteria
    puts "\n🧹 Cleaning up stale jobs..."
    rules = JobWizard::Rules.current
    filter = JobWizard::JobFilter.new(rules.job_filters)
    ranker = JobWizard::JobRanker.new(rules.scoring, rules.ranking)

    removed_count = 0
    JobPosting.find_each do |job|
      keeps = filter.keep?(title: job.title, description: job.description, location: job.location)
      score = ranker.score(title: job.title, description: job.description, location: job.location)

      unless keeps && score.positive?
        job.destroy
        removed_count += 1
      end
    end

    puts "✓ Removed #{removed_count} job(s) that no longer match criteria" if removed_count.positive?
    puts "\nVisit /jobs to view the job board"
  end

  desc 'Clean old job postings (older than 90 days)'
  task clean: :environment do
    cutoff_date = 90.days.ago
    old_jobs = JobPosting.where(created_at: ...cutoff_date)
    count = old_jobs.count

    old_jobs.destroy_all
    puts "Removed #{count} old job posting(s)"
  end

  desc 'Re-evaluate all existing jobs against current filter/scoring rules'
  task refilter: :environment do
    puts 'Re-evaluating all jobs against current rules...'
    puts '=' * 80

    rules = JobWizard::Rules.current
    filter = JobWizard::JobFilter.new(rules.job_filters)
    ranker = JobWizard::JobRanker.new(rules.scoring, rules.ranking)

    total_jobs = JobPosting.count
    removed_count = 0
    updated_count = 0

    JobPosting.find_each do |job|
      # Check if job still passes filter
      keeps = filter.keep?(
        title: job.title,
        description: job.description,
        location: job.location
      )

      if keeps
        # Recalculate score
        new_score = ranker.score(
          title: job.title,
          description: job.description,
          location: job.location
        )

        if new_score.zero?
          # Score is 0 (below threshold), remove it
          puts "  ✗ Removing: #{job.title} (score below threshold)"
          job.destroy
          removed_count += 1
        elsif (job.score - new_score).abs > 0.01
          # Score changed, update it
          old_score = job.score
          job.update!(score: new_score)
          puts "  ↻ Updated: #{job.title} (#{old_score.round(2)} → #{new_score.round(2)})"
          updated_count += 1
        end
      else
        # No longer passes filter, remove it
        puts "  ✗ Removing: #{job.title} (#{job.location || 'no location'})"
        job.destroy
        removed_count += 1
      end
    end

    puts '=' * 80
    puts "Total jobs evaluated: #{total_jobs}"
    puts "Removed (no longer match criteria): #{removed_count}"
    puts "Updated (score changed): #{updated_count}"
    puts "Kept unchanged: #{total_jobs - removed_count - updated_count}"
  end
end

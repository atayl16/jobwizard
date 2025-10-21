# frozen_string_literal: true

namespace :jobs do
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

    jobs_data.each do |job_data|
      job = JobPosting.find_or_initialize_by(url: job_data[:url])

      if job.new_record?
        job.assign_attributes(job_data)
        job.save!
        created_count += 1
      else
        job.update!(job_data)
        updated_count += 1
      end
    end

    # Update source last_fetched_at
    source.mark_as_fetched!

    puts "✓ Fetched #{jobs_data.length} jobs"
    puts "  Created: #{created_count}"
    puts "  Updated: #{updated_count}"
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
end

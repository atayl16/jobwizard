# frozen_string_literal: true

namespace :ai do
  desc 'Smoke test OpenAI cover letter generation (requires OPENAI_API_KEY)'
  task :cover_letter, %i[company role] => :environment do |_t, args|
    company = args[:company] || 'Acme Corp'
    role = args[:role] || 'Senior Rails Engineer'

    if ENV['OPENAI_API_KEY'].blank?
      puts '❌ OPENAI_API_KEY not set. This task requires an OpenAI API key.'
      puts '   Set it with: export OPENAI_API_KEY=your_key_here'
      exit 1
    end

    puts '🔧 OpenAI Cover Letter Smoke Test'
    puts '=' * 60
    puts "Company: #{company}"
    puts "Role: #{role}"
    puts '=' * 60
    puts

    # Load sample JD
    sample_jd_path = Rails.root.join('spec/fixtures/jd/sample.txt')
    unless File.exist?(sample_jd_path)
      puts "Creating sample JD at #{sample_jd_path}..."
      FileUtils.mkdir_p(File.dirname(sample_jd_path))
      File.write(sample_jd_path, <<~JD)
        Senior Rails Engineer

        We are seeking an experienced Senior Rails Engineer to join our growing team.

        Requirements:
        - 5+ years of Ruby on Rails development
        - Strong experience with PostgreSQL and Redis
        - Experience building RESTful APIs
        - Kubernetes and Docker experience preferred
        - Strong communication and mentorship skills

        Responsibilities:
        - Design and implement scalable web applications
        - Lead technical discussions and code reviews
        - Mentor junior engineers
        - Collaborate with product and design teams
      JD
    end

    jd_text = File.read(sample_jd_path)

    # Load profile and experience
    profile_yaml = Rails.root.join('config/job_wizard/profile.yml').read
    experience_yaml = Rails.root.join('config/job_wizard/experience.yml').read

    # Test AI Writer
    begin
      puts '📝 Generating cover letter with OpenAI...'
      writer = JobWizard::Writers::OpenAiWriter.new

      result = writer.cover_letter(
        company: company,
        role: role,
        jd_text: jd_text,
        profile: profile_yaml,
        experience: experience_yaml
      )

      if result[:error]
        puts "❌ Error: #{result[:error]}"
        exit 1
      end

      puts '✅ Cover letter generated successfully!'
      puts
      puts '📄 COVER LETTER:'
      puts '-' * 60
      puts result[:cover_letter]
      puts '-' * 60
      puts

      if result[:unverified_skills].any?
        puts '⚠️  UNVERIFIED SKILLS (not in experience.yml):'
        result[:unverified_skills].each do |skill|
          puts "   - #{skill}"
        end
        puts
      end

      puts '✅ Smoke test completed successfully!'
      puts
      puts "Token usage: #{result.dig(:usage, :total_tokens) || 'N/A'}"
    rescue StandardError => e
      puts "❌ Error during generation: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end

  desc 'Smoke test OpenAI resume snippets generation (requires OPENAI_API_KEY)'
  task :resume, %i[company role] => :environment do |_t, args|
    company = args[:company] || 'Acme Corp'
    role = args[:role] || 'Senior Rails Engineer'

    if ENV['OPENAI_API_KEY'].blank?
      puts '❌ OPENAI_API_KEY not set. This task requires an OpenAI API key.'
      exit 1
    end

    puts '🔧 OpenAI Resume Snippets Smoke Test'
    puts '=' * 60
    puts "Company: #{company}"
    puts "Role: #{role}"
    puts '=' * 60
    puts

    # Load sample JD
    sample_jd_path = Rails.root.join('spec/fixtures/jd/sample.txt')
    jd_text = File.exist?(sample_jd_path) ? File.read(sample_jd_path) : 'Senior Rails Engineer position'

    # Load profile and experience
    profile_yaml = Rails.root.join('config/job_wizard/profile.yml').read
    experience_yaml = Rails.root.join('config/job_wizard/experience.yml').read

    # Test AI Writer
    begin
      puts '📝 Generating resume snippets with OpenAI...'
      writer = JobWizard::Writers::OpenAiWriter.new

      result = writer.resume_snippets(
        company: company,
        role: role,
        jd_text: jd_text,
        profile: profile_yaml,
        experience: experience_yaml
      )

      if result[:error]
        puts "❌ Error: #{result[:error]}"
        exit 1
      end

      puts '✅ Resume snippets generated successfully!'
      puts
      puts '📄 RESUME BULLETS:'
      puts '-' * 60
      result[:resume_snippets].each_with_index do |snippet, i|
        puts "#{i + 1}. #{snippet}"
      end
      puts '-' * 60
      puts

      if result[:unverified_skills].any?
        puts '⚠️  UNVERIFIED SKILLS:'
        result[:unverified_skills].each do |skill|
          puts "   - #{skill}"
        end
      end

      puts '✅ Smoke test completed successfully!'
    rescue StandardError => e
      puts "❌ Error: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end
end

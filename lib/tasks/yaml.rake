# frozen_string_literal: true

namespace :yaml do
  desc 'Validate all YAML configuration files'
  task validate: :environment do
    puts 'Validating YAML configuration files...'
    puts '=' * 60

    validator = JobWizard::YamlValidator.new

    begin
      validator.validate_all!
      puts '✓ All YAML files are valid!'
      puts ''
      puts 'Checked files:'
      puts '  - config/job_wizard/profile.yml'
      puts '  - config/job_wizard/experience.yml'
      puts '  - config/job_wizard/rules.yml'
    rescue JobWizard::YamlValidator::ValidationError => e
      puts '✗ YAML validation failed:'
      puts ''
      puts e.message
      puts ''
      puts 'Please fix the errors above and try again.'
      exit 1
    end
  end

  desc 'Show YAML configuration summary'
  task summary: :environment do
    puts 'YAML Configuration Summary'
    puts '=' * 60

    # Profile
    profile = YAML.safe_load_file(JobWizard::CONFIG_PATH.join('profile.yml'))
    puts "\n📋 Profile:"
    puts "  Name: #{profile['name']}"
    puts "  Email: #{profile['email']}"
    puts "  Location: #{profile['location']}"

    # Experience
    experience = YAML.safe_load_file(JobWizard::CONFIG_PATH.join('experience.yml'))
    loader = JobWizard::ExperienceLoader.new
    puts "\n💼 Experience:"
    puts "  Positions: #{experience['positions']&.count || 0}"

    # Skills by level
    skills_by_level = loader.skills_by_level
    total_skills = skills_by_level.values.flatten.count
    puts "  Skills: #{total_skills}"
    puts "  - Expert: #{skills_by_level[:expert].count}"
    puts "  - Intermediate: #{skills_by_level[:intermediate].count}"
    puts "  - Basic: #{skills_by_level[:basic].count}"

    # Rules
    rules = YAML.safe_load_file(JobWizard::CONFIG_PATH.join('rules.yml'))
    puts "\n🔍 Rules:"
    puts "  Warning rules: #{rules['warnings']&.count || 0}"
    puts "  Blocking rules: #{rules['blocking']&.count || 0}"
    puts "  Info rules: #{rules['info']&.count || 0}"

    if rules['filters']
      puts "  Blocked companies (YAML): #{rules['filters']['company_blocklist']&.reject(&:blank?)&.count || 0}"
      puts "  Blocked companies (DB): #{BlockedCompany.count}"
      puts "  Content blocklist: #{rules['filters']['content_blocklist']&.count || 0}"
    end

    puts ''
  end
end

module JobWizard
  class RulesLoader
    DEFAULT_FILTERS = {
      'company_blocklist' => [],
      'content_blocklist' => ['nsfw', 'adult', 'entertainment', 'porn', 'gambling', 'casino', 'sportsbook',
                              'crypto casino'],
      'require_no_security_clearance' => true,
      'allow_background_checks' => true,
      'allowed_phrases' => ['background check', 'background screening'],
      'excluded_phrases' => ['active security clearance', 'secret clearance', 'ts/sci', 'dod clearance'],
      'required_keywords' => %w[ruby rails],
      'excluded_keywords' => %w[php dotnet .net golang cobol]
    }.freeze

    def initialize(path = Rails.root.join('config/job_wizard/rules.yml'))
      @path = path
      @data = load_yaml
    end

    def filters
      @filters ||= merge_with_defaults(@data['filters'] || {})
    end

    def company_blocklist
      yaml_companies = filters['company_blocklist'].compact_blank
      db_companies = BlockedCompany.pluck(:name)
      (yaml_companies + db_companies).uniq
    end

    def content_blocklist
      filters['content_blocklist']
    end

    def required_keywords
      filters['required_keywords']
    end

    def excluded_keywords
      filters['excluded_keywords']
    end

    def require_no_security_clearance?
      filters['require_no_security_clearance']
    end

    def allow_background_checks?
      filters['allow_background_checks']
    end

    def allowed_phrases
      filters['allowed_phrases']
    end

    def excluded_phrases
      filters['excluded_phrases']
    end

    def compile_regex_patterns(patterns)
      patterns.map do |pattern|
        if pattern.start_with?('/') && pattern.end_with?('/')
          # Extract regex pattern and flags
          match = pattern.match(%r{^/(.+)/([a-z]*)$})
          if match
            regex_pattern = match[1]
            flags = match[2]
            case_insensitive = flags.include?('i')
            Regexp.new(regex_pattern, case_insensitive)
          else
            Regexp.new(Regexp.escape(pattern), true)
          end
        else
          Regexp.new(Regexp.escape(pattern), true)
        end
      end
    rescue RegexpError => e
      Rails.logger.warn "Invalid regex pattern '#{pattern}': #{e.message}"
      Regexp.new(Regexp.escape(pattern), true)
    end

    private

    def load_yaml
      return {} unless File.exist?(@path)

      YAML.safe_load_file(@path) || {}
    rescue StandardError => e
      Rails.logger.error "Failed to load rules.yml: #{e.message}"
      {}
    end

    def merge_with_defaults(filters_data)
      DEFAULT_FILTERS.merge(filters_data) do |_key, default_value, yaml_value|
        case default_value
        when Array
          Array(yaml_value).concat(Array(default_value)).uniq
        else
          yaml_value.nil? ? default_value : yaml_value
        end
      end
    end
  end
end

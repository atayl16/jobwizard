# frozen_string_literal: true

module JobWizard
  # Detects and categorizes skills from job descriptions
  class SkillDetector
    attr_reader :job_description, :experience_loader

    def initialize(job_description)
      @job_description = job_description
      @experience_loader = ExperienceLoader.new
    end

    # Returns hash with verified and unverified skills
    def analyze
      detected_skills = extract_skills_from_jd

      verified = []
      unverified = []

      detected_skills.each do |skill|
        if experience_loader.skill?(skill)
          verified << skill
        else
          unverified << skill
        end
      end

      {
        verified: verified.uniq.sort,
        unverified: unverified.uniq.sort
      }
    end

    private

    def extract_skills_from_jd
      text = job_description.downcase
      skills = []

      # Comprehensive skill patterns
      skill_patterns = [
        # Programming languages
        /\b(ruby|python|javascript|typescript|java|go|rust|php|c\+\+|c#|swift|kotlin|elixir|zig|scala|clojure|haskell|erlang)\b/i,

        # Frameworks and libraries
        /\b(ruby on rails|rails|react|vue|angular|node\.js|express|django|flask|laravel|spring|phoenix|ember|svelte|next\.js|nuxt\.js)\b/i,

        # Databases
        /\b(postgresql|mysql|mongodb|redis|elasticsearch|sqlite|oracle|sql server|cassandra|dynamodb|neo4j)\b/i,

        # Cloud and DevOps
        /\b(aws|azure|gcp|google cloud|docker|kubernetes|terraform|ansible|jenkins|circleci|github actions|gitlab ci|heroku|vercel|netlify)\b/i,

        # Frontend technologies
        /\b(html|css|sass|scss|less|webpack|vite|babel|eslint|prettier|tailwind|bootstrap|material-ui|styled-components)\b/i,

        # Backend technologies
        /\b(api|rest|graphql|grpc|microservices|serverless|lambda|nginx|apache|puma|unicorn|passenger)\b/i,

        # Testing frameworks
        /\b(rspec|jest|cypress|selenium|capybara|minitest|testunit|mocha|chai|jasmine|karma|vitest)\b/i,

        # Tools and platforms
        /\b(git|github|gitlab|bitbucket|jira|confluence|slack|discord|figma|sketch|photoshop|illustrator)\b/i,

        # Methodologies
        %r{\b(agile|scrum|kanban|tdd|bdd|ci/cd|devops|microservices|monolith|mvp|lean)\b}i,

        # Data and analytics
        /\b(sql|nosql|etl|data pipeline|machine learning|ai|artificial intelligence|tensorflow|pytorch|pandas|numpy)\b/i,

        # Security
        /\b(oauth|jwt|ssl|tls|encryption|authentication|authorization|security|penetration testing|vulnerability)\b/i,

        # Mobile
        /\b(ios|android|react native|flutter|swift|kotlin|objective-c|xamarin|cordova|phonegap)\b/i,

        # Other common terms
        /\b(linux|ubuntu|centos|debian|macos|windows|bash|shell|zsh|vim|emacs|vscode|intellij|eclipse)\b/i
      ]

      skill_patterns.each do |pattern|
        matches = text.scan(pattern).flatten
        skills.concat(matches.map(&:strip))
      end

      # Clean up and normalize skills
      skills.map do |skill|
        normalize_skill_name(skill)
      end.compact.uniq
    end

    def normalize_skill_name(skill)
      # Normalize common variations
      normalized = skill.downcase.strip

      # Handle common aliases
      aliases = {
        'js' => 'javascript',
        'ts' => 'typescript',
        'py' => 'python',
        'rb' => 'ruby',
        'rails' => 'ruby on rails',
        'postgres' => 'postgresql',
        'mysql' => 'mysql',
        'mongo' => 'mongodb',
        'k8s' => 'kubernetes',
        'gcp' => 'google cloud platform',
        'aws' => 'amazon web services',
        'azure' => 'microsoft azure'
      }

      aliases[normalized] || normalized.titleize
    end
  end
end


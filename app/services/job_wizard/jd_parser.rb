# frozen_string_literal: true

module JobWizard
  # Lightweight job description parser to extract company name and role title
  # Uses simple heuristics - not ML, just pattern matching
  class JdParser
    attr_reader :text

    def initialize(text)
      @text = text.to_s
    end

    # Extract company name from job description
    def company
      # Try common patterns
      [
        # "Company: Acme Inc" or "Company - Acme Inc"
        /(?:company|organization|employer)[:\-\s]+([A-Z][A-Za-z0-9\s&.,'-]+?)(?:\n|is|has|based)/i,
        # "About Acme Inc" or "About Us: Acme"
        /about\s+(?:us[:\s]+)?([A-Z][A-Za-z0-9\s&.,'-]+?)(?:\n|is|has|we|our)/i,
        # Email domain (e.g., @acmeinc.com)
        /@([a-z0-9-]+)\./i,
        # First line if it's capitalized and short
        /\A([A-Z][A-Za-z0-9\s&.,'-]{2,40})\s*(?:\n|$)/
      ].each do |pattern|
        match = text.match(pattern)
        next unless match

        company_name = match[1].strip
        # Clean up common suffixes
        company_name = company_name.sub(/\s+(Inc|LLC|Ltd|Corporation|Corp|Limited|Company|Co)\.?$/i, '')
        company_name = company_name.strip

        return company_name if company_name.length > 2 && company_name.length < 50
      end

      nil
    end

    # Extract role/title from job description
    def role
      # Try common patterns
      [
        # "Position: Senior Engineer" or "Role - Senior Engineer"
        %r{(?:position|role|title|job title)[:\-\s]+([A-Za-z0-9\s,/.-]+?)(?:\n|at|$)}i,
        # Job title keywords at start of line
        /^([A-Za-z\s]+?(?:Engineer|Developer|Manager|Designer|Analyst|Lead|Director|Architect|Specialist|Coordinator)[A-Za-z\s]*?)(?:\n|at|$)/im,
        # Lines containing "hiring" or "looking for"
        /(?:hiring|looking for|seeking)(?:\s+an?)?([A-Z][A-Za-z\s]+?(?:Engineer|Developer|Manager|Designer|Analyst|Lead|Director|Architect))/i
      ].each do |pattern|
        match = text.match(pattern)
        next unless match

        role_name = match[1].strip
        role_name = role_name.sub(/\s+at\s+.+$/i, '') # Remove "at Company"
        role_name = role_name.strip

        return role_name if role_name.length > 3 && role_name.length < 100
      end

      nil
    end

    # Parse and return both as hash
    def parse
      {
        company: company,
        role: role
      }
    end
  end
end

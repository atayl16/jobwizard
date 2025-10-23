class BlockedCompany < ApplicationRecord
  validates :name, presence: true
  validates :reason, presence: true

  def matches?(company_name)
    return false if company_name.blank?

    if pattern?
      # Treat name as regex pattern
      begin
        regex = Regexp.new(name, true) # case-insensitive
        regex.match?(company_name)
      rescue RegexpError
        # Fallback to case-insensitive string match if regex is invalid
        company_name.downcase.include?(name.downcase)
      end
    else
      # Exact match (case-insensitive)
      company_name.downcase == name.downcase
    end
  end

  def self.matches_company?(company_name)
    return false if company_name.blank?

    find_each.any? { |blocked| blocked.matches?(company_name) }
  end
end

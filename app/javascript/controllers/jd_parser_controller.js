import { Controller } from "@hotwired/stimulus"

// Auto-parse job descriptions to extract company and role
export default class extends Controller {
  static targets = ["description", "company", "role"]

  parse() {
    const text = this.descriptionTarget.value
    
    if (text.length < 20) {
      return // Too short to parse
    }

    // Extract company
    const company = this.extractCompany(text)
    if (company && !this.companyTarget.value) {
      this.companyTarget.value = company
    }

    // Extract role
    const role = this.extractRole(text)
    if (role && !this.roleTarget.value) {
      this.roleTarget.value = role
    }
  }

  extractCompany(text) {
    // Try "Company: XYZ" pattern
    let match = text.match(/(?:company|organization|employer)[:\-\s]+([A-Z][A-Za-z0-9\s&.,'-]+?)(?:\n|is|has|based)/i)
    if (match) {
      return this.cleanCompanyName(match[1])
    }

    // Try "About XYZ" pattern
    match = text.match(/about\s+(?:us[:\s]+)?([A-Z][A-Za-z0-9\s&.,'-]+?)(?:\n|is|has|we|our)/i)
    if (match) {
      return this.cleanCompanyName(match[1])
    }

    // Try email domain
    match = text.match(/@([a-z0-9-]+)\./i)
    if (match) {
      return this.capitalize(match[1])
    }

    // Try first line if capitalized
    match = text.match(/^([A-Z][A-Za-z0-9\s&.,'-]{2,40})\s*(?:\n|$)/)
    if (match) {
      return this.cleanCompanyName(match[1])
    }

    return null
  }

  extractRole(text) {
    // Try "Position: XYZ" pattern
    let match = text.match(/(?:position|role|title|job title)[:\-\s]+([A-Za-z0-9\s,/.-]+?)(?:\n|at|$)/i)
    if (match) {
      return this.cleanRoleName(match[1])
    }

    // Try job title keywords
    match = text.match(/^([A-Za-z\s]+?(?:Engineer|Developer|Manager|Designer|Analyst|Lead|Director|Architect|Specialist|Coordinator)[A-Za-z\s]*?)(?:\n|at|$)/im)
    if (match) {
      return this.cleanRoleName(match[1])
    }

    // Try "hiring/looking for" pattern
    match = text.match(/(?:hiring|looking for|seeking)(?:\s+an?)?([A-Z][A-Za-z\s]+?(?:Engineer|Developer|Manager|Designer|Analyst|Lead|Director|Architect))/i)
    if (match) {
      return this.cleanRoleName(match[1])
    }

    return null
  }

  cleanCompanyName(name) {
    let cleaned = name.trim()
    // Remove common suffixes
    cleaned = cleaned.replace(/\s+(Inc|LLC|Ltd|Corporation|Corp|Limited|Company|Co)\.?$/i, '')
    cleaned = cleaned.trim()
    
    if (cleaned.length > 2 && cleaned.length < 50) {
      return cleaned
    }
    return null
  }

  cleanRoleName(name) {
    let cleaned = name.trim()
    // Remove "at Company" suffix
    cleaned = cleaned.replace(/\s+at\s+.+$/i, '')
    cleaned = cleaned.trim()
    
    if (cleaned.length > 3 && cleaned.length < 100) {
      return cleaned
    }
    return null
  }

  capitalize(str) {
    return str.charAt(0).toUpperCase() + str.slice(1)
  }
}





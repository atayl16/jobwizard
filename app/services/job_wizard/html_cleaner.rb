module JobWizard
  class HtmlCleaner
    def self.clean(html_content)
      return '' if html_content.blank?

      # Decode HTML entities first
      decoded = CGI.unescapeHTML(html_content)

      # Remove script and style tags entirely (including content)
      decoded = decoded.gsub(%r{<script[^>]*>.*?</script>}im, '')
                       .gsub(%r{<style[^>]*>.*?</style>}im, '')

      # Remove HTML tags but preserve basic spacing
      cleaned = decoded.gsub(%r{<br\s*/?>}i, "\n")
                       .gsub(%r{</p>}i, "\n\n")
                       .gsub(%r{</div>}i, "\n")
                       .gsub(%r{</li>}i, "\n")
                       .gsub(%r{</h[1-6]>}i, "\n\n")
                       .gsub(/<[^>]+>/, '') # Remove all remaining HTML tags
                       .gsub('&nbsp;', ' ') # Replace non-breaking spaces
                       .gsub('&amp;', '&') # Decode ampersands
                       .gsub('&lt;', '<') # Decode less than
                       .gsub('&gt;', '>') # Decode greater than
                       .gsub('&quot;', '"') # Decode quotes
                       .gsub('&#39;', "'") # Decode apostrophes
                       .gsub(/\n\s*\n\s*\n/, "\n\n") # Collapse multiple newlines
                       .strip

      # Second pass to handle any remaining entities after tag removal
      CGI.unescapeHTML(cleaned).strip
    end
  end
end

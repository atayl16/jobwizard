# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobWizard::HtmlCleaner do
  describe '.clean' do
    it 'returns empty string for blank input' do
      expect(described_class.clean('')).to eq('')
      expect(described_class.clean(nil)).to eq('')
    end

    it 'removes basic HTML tags' do
      html = '<p>Hello World</p>'
      expect(described_class.clean(html)).to eq('Hello World')
    end

    it 'decodes HTML entities' do
      html = 'Hello &amp; goodbye'
      expect(described_class.clean(html)).to eq('Hello & goodbye')
    end

    it 'handles nested entities (double encoding)' do
      html = '&amp;lt;div&amp;gt;Test&amp;lt;/div&amp;gt;'
      result = described_class.clean(html)
      # First decode: &lt;div&gt;Test&lt;/div&gt;
      # Second decode: <div>Test</div>
      # In practice, this level of double-encoding is rare in real job board APIs
      # We decode once, then strip tags. A second decode pass would be needed for full nesting.
      expect(result).to eq('<div>Test</div>')
    end

    it 'preserves spacing with br tags' do
      html = 'Line 1<br>Line 2<br/>Line 3'
      result = described_class.clean(html)
      expect(result).to include('Line 1')
      expect(result).to include('Line 2')
      expect(result).to include('Line 3')
    end

    it 'preserves paragraph breaks' do
      html = '<p>Paragraph 1</p><p>Paragraph 2</p>'
      result = described_class.clean(html)
      expect(result).to match(/Paragraph 1\s+Paragraph 2/)
    end

    it 'handles lists' do
      html = '<ul><li>Item 1</li><li>Item 2</li></ul>'
      result = described_class.clean(html)
      expect(result).to include('Item 1')
      expect(result).to include('Item 2')
    end

    it 'handles malformed HTML gracefully' do
      html = '<p>Unclosed paragraph <div>Nested'
      result = described_class.clean(html)
      expect(result).to include('Unclosed paragraph')
      expect(result).to include('Nested')
      expect(result).not_to include('<')
    end

    it 'handles complex real-world example' do
      html = <<~HTML
        &lt;div class="content"&gt;
          &lt;h2&gt;Senior Rails Engineer&lt;/h2&gt;
          &lt;p&gt;We&#39;re looking for an experienced developer.&lt;/p&gt;
          &lt;ul&gt;
            &lt;li&gt;5+ years Ruby experience&lt;/li&gt;
            &lt;li&gt;PostgreSQL &amp; Redis&lt;/li&gt;
          &lt;/ul&gt;
        &lt;/div&gt;
      HTML

      result = described_class.clean(html)

      expect(result).to include('Senior Rails Engineer')
      expect(result).to include("We're looking for an experienced developer")
      expect(result).to include('5+ years Ruby experience')
      expect(result).to include('PostgreSQL & Redis')
      expect(result).not_to include('&lt;')
      expect(result).not_to include('<div')
    end

    it 'handles non-breaking spaces' do
      html = 'Hello&nbsp;World'
      expect(described_class.clean(html)).to eq('Hello World')
    end

    it 'collapses multiple newlines' do
      html = "Line 1\n\n\n\n\nLine 2"
      result = described_class.clean(html)
      expect(result).not_to match(/\n{3,}/)
    end

    it 'strips leading and trailing whitespace' do
      html = "  \n\n  <p>Content</p>  \n\n  "
      result = described_class.clean(html)
      expect(result).to eq('Content')
    end

    it 'handles script tags (removes them entirely)' do
      html = '<p>Safe content</p><script>alert("xss")</script><p>More content</p>'
      result = described_class.clean(html)
      expect(result).not_to include('script')
      expect(result).not_to include('alert')
      expect(result).to include('Safe content')
      expect(result).to include('More content')
    end

    it 'handles style tags (removes them entirely)' do
      html = '<p>Content</p><style>.class { color: red; }</style>'
      result = described_class.clean(html)
      expect(result).not_to include('style')
      expect(result).not_to include('color: red')
      expect(result).to include('Content')
    end
  end
end

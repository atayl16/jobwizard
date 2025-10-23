# AI Writer Setup Guide

JobWizard supports AI-powered resume and cover letter generation using OpenAI's GPT models. This is completely **optional** - the app works perfectly fine without it using template-based generation.

## Quick Start

### 1. Get an OpenAI API Key

1. Visit https://platform.openai.com/api-keys
2. Sign up or log in
3. Create a new API key
4. Copy the key (starts with `sk-...`)

### 2. Set Environment Variable

Add to your `.env` file or export in your shell:

```bash
export OPENAI_API_KEY=sk-your-key-here
```

### 3. Test It

```bash
rake ai:cover_letter["Acme Corp","Senior Rails Engineer"]
```

That's it! The app will automatically use AI generation when the key is present.

## Configuration Options

Create a `.env` file in the project root with these optional settings:

```bash
# Required for AI generation
OPENAI_API_KEY=sk-your-key-here

# Optional: Model selection (default: gpt-4o-mini)
# Options: gpt-4o-mini, gpt-4, gpt-4-turbo, gpt-3.5-turbo
# gpt-4o-mini is recommended for cost/quality balance
OPENAI_MODEL=gpt-4o-mini

# Optional: Temperature for resume generation (default: 0.5)
# Lower (0.0) = more focused/consistent
# Higher (2.0) = more creative/varied
OPENAI_TEMP_RESUME=0.5

# Optional: Temperature for cover letters (default: 0.7)
OPENAI_TEMP_COVER_LETTER=0.7

# Optional: Max tokens per generation (default: 800)
# Approximate max length of generated content
OPENAI_MAX_TOKENS=800

# Optional: Explicit writer selection (default: auto-detected)
# 'openai' = use AI when API key present
# 'templates' = always use template-based generation
AI_WRITER=openai
```

## How It Works

### Truth-Only Guarantee

The AI writer follows strict rules:

1. **ONLY uses facts** from your `config/job_wizard/profile.yml` and `experience.yml`
2. **NEVER invents** skills, projects, or achievements
3. **Identifies unverified skills** - if a job description mentions skills you don't have, they're flagged but never claimed

### Fallback System

The AI writer has built-in fallbacks:

```
Try OpenAI Generation
  ↓ (if fails)
Fall back to Template Writer
  ↓ (always works)
Generate resume/cover letter
```

You'll never see an error - if AI generation fails for any reason, the app automatically uses templates.

### What Gets Generated

- **Cover Letter**: 3-4 paragraph letter tailored to the job
- **Resume Snippets**: Bullet points highlighting relevant experience

The Prawn PDF rendering remains unchanged - only the text content is AI-generated.

## Testing

### Manual Smoke Tests

Test cover letter generation:
```bash
rake ai:cover_letter["Google","Staff Engineer"]
```

Test resume snippets:
```bash
rake ai:resume["Amazon","Senior Backend Developer"]
```

These tasks:
- ✅ Only run if `OPENAI_API_KEY` is set
- ✅ Use a sample job description from `spec/fixtures/jd/sample.txt`
- ✅ Print the generated content to your terminal
- ✅ Show any unverified skills

### Automated Tests

All tests stub network calls by default (no API key required):

```bash
bundle exec rspec spec/services/job_wizard/writers/open_ai_writer_spec.rb
```

## Cost Considerations

### Pricing (as of 2024)

- **gpt-4o-mini**: ~$0.15 per 1M input tokens, ~$0.60 per 1M output tokens
- **gpt-4**: ~$30 per 1M input tokens, ~$60 per 1M output tokens

### Typical Usage

One resume + cover letter generation:
- Input: ~2,000 tokens (your profile + experience + JD)
- Output: ~800 tokens (generated text)

**Cost per application with gpt-4o-mini**: ~$0.001 (one-tenth of a cent)

### Recommendations

1. **Start with gpt-4o-mini** - excellent quality, very cheap
2. **Use templates for bulk** - if generating 50+ applications, consider templates
3. **Monitor usage** - check your OpenAI dashboard: https://platform.openai.com/usage

## Troubleshooting

### "Client not available" error

**Cause**: OpenAI gem couldn't initialize client  
**Fix**: Check your API key is valid and starts with `sk-`

### Falls back to templates every time

**Causes**:
1. `OPENAI_API_KEY` not set → Set it in your environment
2. `AI_WRITER=templates` explicitly set → Remove or set to `openai`
3. API key invalid → Check at https://platform.openai.com/api-keys

### Rate limit errors

**Cause**: Too many requests  
**Fix**: OpenAI has rate limits for new accounts. Wait a few seconds between generations or upgrade your OpenAI account tier.

## Privacy & Security

### Local-Only

- All processing happens on your machine
- Only the job description text is sent to OpenAI
- Your generated resumes never leave your computer

### What Gets Sent to OpenAI

1. Job description text (after HTML cleaning)
2. Your profile YAML (name, email, summary)
3. Your experience YAML (skills, positions)

### What Does NOT Get Sent

- Your actual generated PDFs
- File paths
- Database contents
- Job application history

## Disabling AI Generation

To permanently disable AI generation:

1. Remove `OPENAI_API_KEY` from environment
2. Or set `AI_WRITER=templates`

The app will use high-quality templates instead (same as before AI integration).

## Examples

### Successful Generation

```bash
$ rake ai:cover_letter["Stripe","Senior Rails Engineer"]
🔧 OpenAI Cover Letter Smoke Test
============================================================
Company: Stripe
Role: Senior Rails Engineer
============================================================

📝 Generating cover letter with OpenAI...
✅ Cover letter generated successfully!

📄 COVER LETTER:
------------------------------------------------------------
Dear Stripe Hiring Team,

I am excited to apply for the Senior Rails Engineer position...

[Full letter content]
------------------------------------------------------------

✅ Smoke test completed successfully!
```

### Unverified Skills Warning

```bash
⚠️  UNVERIFIED SKILLS (not in experience.yml):
   - Kubernetes Operators
   - Terraform Enterprise

These skills were mentioned in the JD but NOT included in
the generated letter (truth-only guarantee).
```

## Advanced Usage

### Custom Model

```bash
OPENAI_MODEL=gpt-4 rake ai:cover_letter["OpenAI","ML Engineer"]
```

### Integration Testing

See `spec/services/job_wizard/writers/open_ai_writer_spec.rb` for examples of:
- Stubbing OpenAI responses
- Testing fallback behavior
- Verifying truth-only guarantees

## Support

If you encounter issues:

1. Check this guide first
2. Run `rake ai:cover_letter` to test your setup
3. Check Rails logs for detailed error messages
4. Verify your OpenAI API key is active

## Future Enhancements

Potential improvements (not yet implemented):

- [ ] Streaming generation for real-time feedback
- [ ] Caching frequently-used prompts
- [ ] A/B testing different temperatures
- [ ] Custom system prompts per user
- [ ] Support for other AI providers (Anthropic, local models)

---

**Remember**: AI generation is opt-in. JobWizard works great with or without it!




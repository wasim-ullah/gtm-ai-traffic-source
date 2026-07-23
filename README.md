# AI Traffic Source — GTM Variable Template

A Google Tag Manager variable template that detects visits referred by AI assistants and answer engines, so you can measure how much of your traffic comes from LLMs and report on it in GA4.

Built by [SanityAI](https://sanity.ai), an AI automation and marketing agency.

## What it detects

| Source label | Matched referrer domains | Matched utm_source values |
|---|---|---|
| `chatgpt` | chatgpt.com, chat.openai.com, openai.com | chatgpt, chatgpt.com, openai |
| `perplexity` | perplexity.ai, pplx.ai | perplexity, perplexity.ai |
| `gemini` | gemini.google.com, bard.google.com, aistudio.google.com | gemini, bard |
| `claude` | claude.ai, claude.com | claude, anthropic |
| `copilot` | copilot.microsoft.com, copilot.cloud.microsoft, edgeservices.bing.com | copilot, ms_copilot, bingchat |
| `grok` | grok.com, x.ai | grok, xai |
| `deepseek` | deepseek.com, chat.deepseek.com | deepseek |
| `meta_ai` | meta.ai | meta_ai, metaai |
| `mistral` | mistral.ai, chat.mistral.ai | mistral, lechat |
| `you` | you.com | you.com |
| `poe` | poe.com | poe |
| `phind` | phind.com | phind |

Subdomains are matched automatically (e.g. `www.perplexity.ai` matches `perplexity.ai`). You can extend the list with your own `domain:label` pairs in the template settings.

## Why utm_source detection matters

AI assistants increasingly strip or generalize the referrer on outbound clicks. ChatGPT, for example, appends `utm_source=chatgpt.com` to links it cites. This template checks both the referrer hostname and the `utm_source` / `ref` query parameters, so those visits are still attributed correctly. UTM detection can be disabled in the template settings if you prefer referrer-only classification.

## Installation

**From the Community Template Gallery (once published):**
Templates → Search Gallery → search "AI Traffic Source" → Add to workspace.

**Manual import:**
1. Download `template.tpl` from this repository.
2. In GTM: Templates → Variable Templates → New → ⋮ menu → Import.
3. Select the file and Save.
4. Variables → New → choose "AI Traffic Source" under Custom Templates.

## Template settings

- **Output type**: `AI source name` returns a label like `chatgpt` (or the fallback value for non-AI traffic). `Boolean` returns `true`/`false`.
- **UTM detection**: on by default, catches AI visits with stripped referrers.
- **Additional AI domains**: comma-separated `domain:label` pairs, e.g. `kagi.com:kagi, andisearch.com:andi`.
- **Fallback value**: what to return for non-AI traffic, e.g. `(none)`. Empty returns `undefined`.

## Recommended GA4 setup

1. **Create the variable**: name it `AI Traffic Source`, output type `AI source name`, fallback value `(none)`.

2. **Create a trigger** (fires only on AI-referred pageviews):
   - Type: Page View
   - Fire on: Some Page Views
   - Condition: `AI Traffic Source` → does not equal → `(none)`

3. **Create a GA4 Event tag**:
   - Event name: `ai_referral`
   - Event parameter: `ai_source` = `{{AI Traffic Source}}`
   - Trigger: the trigger from step 2

4. **Register the custom dimension in GA4**:
   - Admin → Custom definitions → Create custom dimension
   - Dimension name: `AI Source`, scope: Event, event parameter: `ai_source`

Within 24–48 hours you can build GA4 reports and explorations segmented by AI source, and use `ai_referral` as a step in funnels to measure whether AI-referred visitors convert differently.

## Development

To modify this template:
1. Import `template.tpl` into the GTM template editor.
2. Make changes there (the editor validates permissions and lets you run the built-in tests).
3. Run the tests in the Tests tab — all scenarios should pass.
4. Export from the editor and replace the contents of `template.tpl`.

Do not hand-edit `template.tpl` for anything beyond trivial changes; the GTM editor is the source of truth for formatting.

## License

Apache 2.0 — see [LICENSE](LICENSE).

## Issues

Found a new AI platform we should detect, or a false positive? Open an issue — the domain list is designed to be extended.

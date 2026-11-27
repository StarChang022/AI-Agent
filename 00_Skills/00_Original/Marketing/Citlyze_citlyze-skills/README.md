# Citlyze Agent Skills

Agent skills for [Citlyze](https://www.citlyze.com), the AI search visibility platform. These skills teach AI coding agents (Claude Code, Codex, Cursor, Gemini CLI, VS Code, and any tool that reads the [Agent Skills](https://agentskills.io) `SKILL.md` standard) how to analyze brand visibility in ChatGPT, Claude, Perplexity, Gemini, and Google AI Overviews - and how to audit pages for AI search readiness.

One format, every tool: the skills follow the open SKILL.md standard, so the same files work across all supporting agents. No per-tool versions needed.

## Skills

| Skill | What it does | Needs Citlyze? |
| --- | --- | --- |
| [aeo-page-audit](skills/aeo-page-audit/SKILL.md) | Grade any page /100 for AI crawlability and answer extractability | **No** - works standalone |
| [citlyze-visibility-report](skills/citlyze-visibility-report/SKILL.md) | Window-over-window AI visibility report with per-engine deltas and competitor standings | Yes (MCP) |
| [citlyze-citation-gap](skills/citlyze-citation-gap/SKILL.md) | Classify cited domains by channel and content type, build an outreach/content target list | Yes (MCP) |
| [citlyze-prompt-audit](skills/citlyze-prompt-audit/SKILL.md) | Find underperforming tracked prompts and coverage gaps, suggest prompts to add | Yes (MCP) |
| [citlyze-action-plan](skills/citlyze-action-plan/SKILL.md) | Turn recommendations into a sequenced two-week action plan with an impact/effort matrix | Yes (MCP) |

## Install

With the [skills CLI](https://skills.sh) (works for Claude Code, Codex, Cursor, and more):

```bash
npx skills add Citlyze/citlyze-skills
```

Or manually: clone this repo and copy the folders under `skills/` into your agent's skills directory (for Claude Code, `~/.claude/skills/` globally or `.claude/skills/` per project; see [agentskills.io](https://agentskills.io) for other tools).

## Connect Citlyze (for the MCP-based skills)

The four `citlyze-*` skills read live workspace data through the Citlyze MCP server:

- Endpoint: `https://app.citlyze.com/api/mcp` (streamable HTTP, read-only)
- Auth: workspace API key as a bearer token, created at [app.citlyze.com/workspace-settings](https://app.citlyze.com/workspace-settings)
- Setup guides for every client: [citlyze.com/docs/mcp/overview](https://www.citlyze.com/docs/mcp/overview)
- Client configs and the MCP artifacts live in [Citlyze/citlyze-mcp](https://github.com/citlyze/citlyze-mcp)

`aeo-page-audit` needs no account: it uses your agent's own fetch tools and the same public checklist as the free [AEO grader](https://www.citlyze.com/free-tools/aeo-grader).

For a deterministic version of the same check that also runs in CI, fails pull requests on regressions, and compares the initial HTML with the rendered page, use [ai-readable](https://github.com/citlyze/ai-readable): `npx ai-readable <url> --render`, or install its skill with `npx skills add Citlyze/ai-readable`.

## About Citlyze

[Citlyze](https://www.citlyze.com) tracks how brands show up in AI search: visibility scores per engine, tracked prompts, citations, competitor comparisons, optimization recommendations, and AI crawler analytics. These skills are MIT licensed - use them, fork them, adapt them.

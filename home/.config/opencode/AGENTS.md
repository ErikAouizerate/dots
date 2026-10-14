<!-- context7 -->
Use Context7 MCP to fetch current documentation whenever the user asks about a library, framework, SDK, API, CLI tool, or cloud service — even well-known ones like React, Next.js, Prisma, Express, Tailwind, Django, or Spring Boot. This includes API syntax, configuration, version migration, library-specific debugging, setup instructions, and CLI tool usage. Use even when you think you know the answer — your training data may not reflect recent changes. Prefer this over web search for library docs.

Do not use for: refactoring, writing scripts from scratch, debugging business logic, code review, or general programming concepts.

## Steps

1. Always start with `resolve-library-id` using the library name and what to look up in the library's documentation, unless the user provides an exact library ID in `/org/project` format
2. Pick the best match (ID format: `/org/project`) by: exact name match, description relevance, code snippet count, source reputation (High/Medium preferred), and benchmark score (higher is better). If results don't look right, try alternate names or queries (e.g., "next.js" not "nextjs", or rephrase the question). Use version-specific IDs when the user mentions a version
3. `query-docs` with the selected library ID and what to look up in the library's documentation (not single words), scoped to a single concept. If the question spans multiple distinct concepts (e.g. routing and auth and caching), make a separate `query-docs` call per concept with the same library ID, unless the question is about how the concepts interact — combined queries dilute ranking and return shallow results for each topic
4. Answer using the fetched docs
<!-- context7 -->

## Project scaffolding (Basic Memory)

When the user asks to bootstrap or set up a new project — e.g. "set up my project with a webapp and a Python backend", "je veux le setup de mon projet avec ..." — do not improvise. Read the scaffolding blueprint in Basic Memory and follow it exactly:

- `memory://main/guidelines/project-scaffolding-instructions-for-new-projects`

It explains how to map the request to subprojects, filter policies by scope (`metadata_filters={"scope": ...}`), and generate per-folder AGENTS.md files referencing the applicable `memory://` policies.

## Fast iterations, agile for agents

- **Iterate fast, ship small.** A big feature request gets cut into small slices; do not attempt it in one shot.
- **But keep the big picture.** Before slicing, load the `vibe-wise` skill and use it to discuss the overall goal with the user and map it out, so contradictions and dead ends surface early in the iteration process instead of after several slices.
- **Focus on the essential.** Skip anything not needed for the current slice — no over-engineering, no speculative abstraction (see ponytail rules).
- **Every project README.md states the command(s) to run and what they are supposed to do.** One line per command: what it does, expected outcome.
- **Goal: a working, controlled product first.** A clean rewrite or refactor comes only once the product is built and proven.

## Code reviews

For code reviews (superpowers `requesting-code-review`, SDD task reviews and scoped re-reviews), dispatch the `reviewer` subagent instead of `general` — it runs on `opencode-go/glm-5.3-flash#max`, read-only (the default since the spec 11 A/B: it surfaced real issues the other reviewer missed, latency accepted).

Only two models may ever run a review: `opencode-go/glm-5.3-flash#max` (default, via `agents/reviewer.md`) and `opencode-go/kimi-k2.7-code` (escalation). For the final whole-branch review, escalate by passing `model: "opencode-go/kimi-k2.7-code"`. Never pass `kimi-k3`, `deepseek-v4-pro` or any other model as a review model, whatever the superpowers Model Selection rule suggests.

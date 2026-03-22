# Organization Development Standards

## Security
- Never commit secrets, API keys, or credentials to source control
- All infrastructure must be configuration-swappable (no hardcoded endpoints)
- Use environment variables for all external service URLs and connection strings
- Secrets belong in vault/key management, not in code or config files

## Code Quality
- All code must have unit test coverage for public methods
- Run linters and formatters before committing
- Follow the project-level CLAUDE.md for stack-specific conventions
- Prefer production-ready implementations over stubs or placeholders
- Keep implementations complete — no TODO placeholders in committed code

## Git Workflow
- Feature branches from main (naming: feature/description, bugfix/description)
- Descriptive commit messages (imperative mood, explain why not what)
- No force pushes to shared branches
- Squash-merge feature branches to keep main history clean

## Communication
- Be direct and concise in explanations
- Show code rather than describing code
- When presenting options, lead with the recommended approach

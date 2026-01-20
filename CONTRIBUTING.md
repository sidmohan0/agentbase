# Contributing to AgentBase

Thanks for your interest in contributing to AgentBase!

## Ways to Contribute

### Report Issues

Found a bug or have a feature request? [Open an issue](https://github.com/YOUR_USERNAME/agentbase/issues/new) with:
- Clear description of the problem or request
- Steps to reproduce (for bugs)
- Your environment (OS, Claude Code version)

### Improve Documentation

Documentation improvements are always welcome:
- Fix typos or unclear explanations
- Add examples for different project types
- Translate to other languages

### Submit Code Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Make your changes
4. Test with Claude Code
5. Submit a pull request

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/agentbase.git
cd agentbase

# Create a test project
mkdir /tmp/test-project && cd /tmp/test-project
git init
npm init -y

# Link your development version
mkdir -p .claude/skills
ln -s /path/to/your/agentbase/skill .claude/skills/agentbase

# Test
claude
/agentbase init
```

## Code Style

### SKILL.md

- Use clear markdown formatting
- Keep command descriptions concise
- Include examples for complex features
- Use code blocks with language hints

### Shell Scripts

- Use `set -euo pipefail`
- Add comments for non-obvious logic
- Support both macOS and Linux
- Handle edge cases gracefully

## Testing

Since AgentBase is a Claude Code skill, testing is manual:

1. **Init test**: Run `/agentbase init` on a fresh repo
2. **Status test**: Run `/agentbase status` with scaffolding
3. **Worker test**: Run `/agentbase work <workstream>` and verify sub-agent spawns
4. **Worktree test**: Run `/agentbase worktree <name>` and verify isolation

Document your testing in the PR.

## Pull Request Process

1. **Title**: Use conventional commits (`feat:`, `fix:`, `docs:`)
2. **Description**: Explain what and why
3. **Testing**: Describe how you tested
4. **Screenshots**: Include if UI/output changed

## Questions?

Open a discussion or reach out to the maintainers.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

# Security policy

## Supported version

Security fixes are made against the latest release. Update by running the installer again
before reporting a problem that may already be fixed.

## Report a vulnerability

Use GitHub's **Report a vulnerability** form in the repository's Security tab. Please do not
open a public issue for a vulnerability involving installer integrity, command construction,
permission handling, or unintended access to user files.

Include the Claude KISS version, Claude Code version, operating system, reproduction steps,
and the impact you observed. Remove credentials, tokens, private source, and personal paths
from logs before attaching them.

You should receive an acknowledgement within seven days. Findings will be validated,
prioritized by impact and exploitability, fixed on `main`, and disclosed with the release
that contains the fix.

## Boundary

Claude KISS changes Claude Code defaults; it is not a sandbox. `Bash`, loaded settings,
hooks, plugins, repository instructions, and explicitly configured MCP servers retain their
normal power. Reports about those upstream or user-configured components should go to their
respective maintainers unless Claude KISS activates them unexpectedly.

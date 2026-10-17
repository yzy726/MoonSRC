# Local hooks

Opt in with `git config core.hooksPath .githooks`. This command changes only this
repository. Hook installation is optional; CI runs the complete acceptance suite.

- pre-commit checks formatting and native types, denying warnings.
- commit-msg checks Conventional Commit subjects and permits merge commits.
- pre-push runs native tests. It does not push by itself.

The initial acceptance session is explicitly local: no Git push and no Mooncakes
publication. Full commands and platform evidence are in docs/TESTING.md.

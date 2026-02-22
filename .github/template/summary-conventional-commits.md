# ❌ Conventional Commits Validation Failed

One or more commits in this branch do not follow the [Conventional Commits](https://www.conventionalcommits.org) specification.

## What is Conventional Commits?

Conventional Commits is a standardised format for commit messages that makes it easier to generate changelogs, determine semantic version bumps, and automate releases.

**Format:** `<type>(<scope>): <description>`

| Type | When to use |
|---|---|
| `feat` | A new feature |
| `fix` | A bug fix |
| `docs` | Documentation changes only |
| `style` | Formatting, missing semicolons, etc. (no logic change) |
| `refactor` | Code change that is neither a fix nor a feature |
| `perf` | Performance improvement |
| `test` | Adding or correcting tests |
| `build` | Changes to build system or dependencies |
| `ci` | Changes to CI/CD configuration |
| `chore` | Other changes that don't modify source or test files |
| `revert` | Reverts a previous commit |

**Breaking changes:** Add `!` after the type: `feat!: remove deprecated endpoint`

## Invalid Commits in This Run

```
{{INVALID_COMMITS_LIST}}
```

## How to Fix

### Option 1 — Amend the last commit
```bash
git commit --amend -m "feat: your corrected message here"
```

### Option 2 — Interactive rebase (multiple commits)
```bash
git rebase -i HEAD~{{INVALID_COMMITS_COUNT}}
# Change "pick" to "reword" for each invalid commit, then save and edit messages
```

### Option 3 — Use a commit helper
```bash
npx git-cz        # interactive commit wizard
npx commitizen    # alternative commit wizard
```

## Useful Links

- [Conventional Commits Specification](https://www.conventionalcommits.org/en/v1.0.0/)
- [commitlint Rules Reference](https://commitlint.js.org/#/reference-rules)
- [git rebase documentation](https://git-scm.com/docs/git-rebase)
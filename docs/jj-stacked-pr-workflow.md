# JJ Stacked PR Workflow (VoiceToText)

**Last updated:** February 7, 2026  
**Audience:** Developers and coding agents working in parallel with Jujutsu (`jj`) and GitHub.

## Goal

Use `jj` for stacked changesets while still pushing normal Git branches for GitHub PRs, with minimal branch switching pain.

## Core Mental Model

1. In `jj`, you work on commits, not on a checked-out branch.
2. Git branches are represented by `jj` bookmarks.
3. For GitHub PRs, each reviewable layer in the stack gets its own bookmark.
4. Stacked PRs are created by setting PR base branches in GitHub:
- PR-X: `feat/x` -> `main`
- PR-Y: `feat/y` -> `feat/x`

## One-Time Setup

```bash
# inside repo
jj git init                    # if not already initialized
jj config set --repo user.name "Your Name"
jj config set --repo user.email "you@example.com"
jj git fetch
jj bookmark track main --remote=origin
```

## Daily Start

```bash
jj git fetch
jj new main@origin
jj st
```

`jj new main@origin` starts a fresh line of work from the latest remote main.

## Create a Two-Layer Stack (Feature X -> Feature Y)

```bash
# commit X
# edit files for feature X
jj commit -m "feat: feature X"

# commit Y (depends on X)
# edit files for feature Y
jj commit -m "feat: feature Y"

# inspect
jj log
```

Typical positions after the two commits:

1. `@-` is `feature Y` commit
2. `@--` is `feature X` commit

## Publish Stack to GitHub Branches

```bash
jj git push --named feat/x=@-- --named feat/y=@-
```

This creates/tracks bookmarks and pushes them as remote branches.

## Open Stacked PRs in GitHub

1. PR for X: `feat/x` -> `main`
2. PR for Y: `feat/y` -> `feat/x`

Now reviewers can merge X first, then Y.

## Update Lower Commit (X) After Review

```bash
jj edit feat/x
# apply fixes
jj commit --amend

# push both branches so dependent PR updates too
jj git push --bookmark feat/x --bookmark feat/y
```

`jj` restacks descendants automatically; resolve conflicts if prompted.

## After X Merges

Option A (UI only):
1. Change PR-Y base in GitHub from `feat/x` to `main`.

Option B (local restack):

```bash
jj git fetch
jj rebase -s feat/y -d main@origin
jj bookmark set feat/y -r feat/y
jj git push --bookmark feat/y
```

## Parallel Agent Workflow

Use separate workspaces so each agent has its own directory and working copy.

```bash
jj workspace add ../VoiceToText-agent-a
jj workspace add ../VoiceToText-agent-b
jj workspace list
```

Recommended:

1. One workspace per agent/task.
2. One bookmark namespace per agent, for example:
- `feat/agent-a/<topic>`
- `feat/agent-b/<topic>`
3. Avoid sharing the same bookmark across active agents.

## Naming Conventions

Bookmarks (Git branches):

1. `feat/<topic>`
2. `fix/<topic>`
3. `chore/<topic>`
4. `stack/<topic>/1`, `stack/<topic>/2` for explicit layered stacks

Commit messages:

1. `feat: ...`
2. `fix: ...`
3. `docs: ...`
4. Keep each commit reviewable independently.

## Useful Commands Cheat Sheet

```bash
jj st
jj log
jj new main@origin
jj edit <rev>
jj commit -m "..."
jj commit --amend
jj rebase -s <source> -d <dest>
jj bookmark list --all-remotes
jj bookmark set <name> -r <rev>
jj git fetch
jj git push --bookmark <name>
jj git push --named <name>=<rev>
jj workspace add ../<folder>
jj workspace list
jj workspace update-stale
```

## Common Gotchas

1. `jj git push --bookmark main` may refuse creating remote bookmark if untracked.
- Fix: `jj bookmark track main --remote=origin`

2. Two workspaces moving the same bookmark can cause bookmark conflicts.
- Fix: keep bookmark ownership per agent/task.

3. If another workspace rewrites your parent commit, your workspace may be stale.
- Fix: `jj workspace update-stale`

4. Empty author warnings on commits.
- Fix: set `jj` user name/email and run `jj metaedit --update-author` for current working copy commit if needed.

## Team Policy (Recommended)

1. Keep stacks small (2-5 commits).
2. Each commit should compile or at least be coherent for review.
3. Push bookmarks early to avoid local-only drift.
4. Use one workspace per active agent to eliminate branch switching.
5. Prefer explicit PR chains (`Y -> X`) when stack semantics matter.

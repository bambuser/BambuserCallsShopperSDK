# Scripts

Internal release tooling. **This folder is not published to the public
GitHub mirror** — `prepare-release.sh` uses `rsync --exclude Scripts/`
when it builds the staging directory, and `push-to-github.sh` verifies
`Scripts/` isn't in the staging tree before pushing.

## What each script does

| File                          | Purpose                                                                          |
| ----------------------------- | -------------------------------------------------------------------------------- |
| `release.sh`                  | Orchestrator — the one you run.                                                  |
| `validate-release.sh`         | Pre-flight checks (version format, clean git, [Unreleased] has content).         |
| `changelog-updater.py`        | Move [Unreleased] entries into a new `## [X.Y.Z] - YYYY-MM-DD` section.          |
| `changelog-parser.py`         | Extract a version's entry from CHANGELOG.md into `build/release-notes.md`.       |
| `prepare-release.sh`          | Build the public-facing staging directory in `build/release/`.                   |
| `push-to-github.sh`           | Clone public GitHub repo, mirror staging over it, commit + tag + push.           |
| `publish-github-release.sh`   | Create the GitHub Release entry via `gh` CLI.                                    |
| `cleanup-build.sh`            | Delete `build/`.                                                                 |

## Usage

Cut a release:

```bash
./Scripts/release.sh --version 0.3.1
```

Dry-run to see what would happen without pushing anything:

```bash
./Scripts/release.sh --version 0.3.1 --dry-run
```

Skip the GitHub Release entry (tag is still pushed):

```bash
./Scripts/release.sh --version 0.3.1 --no-gh-release
```

## Prerequisites

- macOS or Linux with `bash`, `git`, `python3`, `rsync`
- SSH access to `git@github.com:bambuser/BambuserCallsShopperSDK.git`
  (or set `GITHUB_REMOTE` env)
- `gh` CLI authenticated (`gh auth login`) — optional; skipped if
  missing
- Working tree on this repo must be clean before running

## What ends up on GitHub

Everything that lives at the repo root except:

- `Scripts/` (this folder)
- `.gitlab-ci.yml`, `.gitlab/`
- `build/` (release output — created by the scripts themselves)
- `xcuserdata/` and `*.xcuserdata/` directories
- `.DS_Store`
- `README.internal.md`, `RELEASE_NOTES.md` (if present)

`rsync --delete` on the mirror step means files removed from the
internal repo are also removed from the public one.

## What ends up in a release commit

- Commit message: `Release vX.Y.Z`
- Tag: `vX.Y.Z` (annotated)
- Author: whoever runs the script (or the `Bambuser Release Bot`
  fallback if git config is empty)
- GitHub Release title: `vX.Y.Z`, body from the CHANGELOG entry

## Workflow expectations

1. Land your feature work on the internal `main` (or release branch).
2. Add entries to `## [Unreleased]` in `CHANGELOG.md` — one per
   ticket, using the tag+title format.
3. When ready, run `./Scripts/release.sh --version X.Y.Z`.
4. The script promotes the [Unreleased] section to [X.Y.Z],
   commits back to the internal repo, then mirrors + tags on GitHub.

## Environment overrides

| Variable         | Default                                                    |
| ---------------- | ---------------------------------------------------------- |
| `GITHUB_REMOTE`  | `git@github.com:bambuser/BambuserCallsShopperSDK.git`      |
| `GITHUB_BRANCH`  | `main`                                                     |

Handy when publishing a test release to a fork.

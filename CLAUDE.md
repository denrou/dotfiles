# dotfiles

Personal repository outside Centreon: the owner is `denrou`, not a Centreon organisation.

- The repository is public: never commit a secret, a token, or a colleague's name.
- Work directly on `main`; no feature branch, no pull request, no `create-pr` skill.
- Commit when asked. Pushing `main` is blocked by the harness deny list, so after committing give
  me the `git push origin main` command to run myself with `!`.
- After adding or removing a script in `bin/`, run `./install.sh` so `~/.local/bin` follows.
- English only, as everywhere else.

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Add user-visible changes under the `[Unreleased]` heading below as you work.
On the next `npm run release:*`, `increment_version.js` promotes `[Unreleased]`
to a dated `[X.Y.Z]` section and inserts a fresh empty `[Unreleased]` above it
along with the comparison links — do not edit the heading or the links by hand.

## [Unreleased]

## [1.2.2] - 2026-10-26

### Fixed

- Plugin silently failed to register (and so never appeared in the plugin list) on servers without `MIME::Lite` installed. Reports are now emailed with Koha's own `Koha::Email` and the default SMTP server, so the plugin has no dependencies beyond Koha itself.

## [1.2.1] - 2026-10-26

### Added

- GitHub Actions workflow that runs the plugin tests against Koha main, stable and oldstable, and builds and publishes the `.kpz` on `v*.*.*` tags.
- `check_release_ready.js` and `ensure_workflows_enabled.js` release preflight scripts, and `CHANGELOG.md` promotion in `increment_version.js`.
- `DEVELOPMENT.md`, `AGENTS.md` and `CLAUDE.md`.

### Changed

- Default email recipients no longer include a named individual's address.
- `t/00-load.t` now checks instantiation and that the plugin version matches `package.json`.

### Removed

- `build.sh`; `.kpz` files are now built by the release workflow.

[Unreleased]: https://github.com/openfifth/koha-plugin-plr/compare/v1.2.2...HEAD
[1.2.2]: https://github.com/openfifth/koha-plugin-plr/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/openfifth/koha-plugin-plr/compare/v1.2.0...v1.2.1
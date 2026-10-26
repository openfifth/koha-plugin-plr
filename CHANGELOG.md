# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Add user-visible changes under the `[Unreleased]` heading below as you work.
On the next `npm run release:*`, `increment_version.js` promotes `[Unreleased]`
to a dated `[X.Y.Z]` section and inserts a fresh empty `[Unreleased]` above it
along with the comparison links — do not edit the heading or the links by hand.

## [Unreleased]

### Added

- The report page now warns when no reports are configured (and hides the Generate and Send buttons), and lists any configured rows skipped for a missing authority code or name. The configuration page shows the same hint when the Reports table is empty.
- Sending with no reports configured now reports "No reports configured", and the nightly auto-send logs a warning instead of silently doing nothing.

## [1.3.2] - 2026-10-26

### Fixed

- Adding the first report on a fresh install produced fields named `authority_code_NaN` because the report count started empty instead of 0.

### Changed

- Minimum Koha version is now 24.11.
- The configuration and report pages use Koha's staff plugin template wrapper, so the page layout, breadcrumbs and side menu match the rest of the staff interface (Administration for configuration, Reports for the report page).

## [1.3.1] - 2026-10-26

### Changed

- "Email From" is now optional and no longer defaults to a hard-coded address. When blank, Koha's default sender address (`KohaAdminEmailAddress`) is used. An existing `mail@openfifth.co.uk` setting is cleared on upgrade.

## [1.3.0] - 2026-10-26

### Added

- "Send history" table on the PLR Reports page listing the 50 most recent returns from the message queue, with status and any failure code.

### Changed

- Reports are now queued in Koha's message queue (letter code `PLR_RETURN`) and sent immediately, so every return has a `message_queue` record with its status and any failure code. Queued messages have no patron, so core does not show them on any patron's Notices tab; use the new send history on the PLR Reports page.

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

[Unreleased]: https://github.com/openfifth/koha-plugin-plr/compare/v1.3.2...HEAD
[1.3.2]: https://github.com/openfifth/koha-plugin-plr/compare/v1.3.1...v1.3.2
[1.3.1]: https://github.com/openfifth/koha-plugin-plr/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/openfifth/koha-plugin-plr/compare/v1.2.2...v1.3.0
[1.2.2]: https://github.com/openfifth/koha-plugin-plr/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/openfifth/koha-plugin-plr/compare/v1.2.0...v1.2.1
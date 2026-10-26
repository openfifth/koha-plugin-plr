# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## What this is

A Koha plugin (`Koha::Plugin::Com::OpenFifth::PLR`) that builds Public Lending Right returns for the British Library from the `statistics` table and emails them. It runs inside Koha, so there is no standalone runtime: `C4::Context`, `Koha::Plugins::Base` and the DB come from a Koha instance (use KTD).

The release tooling mirrors `../koha-plugin-template`; see `DEVELOPMENT.md` for the full workflow, and re-sync from the template rather than diverging.

## Commands

```bash
prove -l t/00-load.t                # only test; needs Koha's @INC and KOHA_PLUGIN_DIR (run in KTD, as CI does)
npm run version:patch|minor|major   # bump package.json + $VERSION + date_updated in PLR.pm; promote CHANGELOG [Unreleased]
npm run release:patch|minor|major   # preflight, bump, commit "chore: bump version", tag vX.Y.Z, and PUSH to origin main
```

`release:*` pushes and tags immediately; don't run it without being asked. It must be run from a clean, up-to-date `main`. The `.kpz` is not built locally: the `v*.*.*` tag triggers `.github/workflows/main.yml`, which tests against Koha main/stable/oldstable, builds the kpz and publishes the GitHub release.

`increment_version.js` rewrites `our $VERSION = '...'` and `date_updated => '...'` with regexes, so keep those two lines in that format. Add user-visible changes under `[Unreleased]` in `CHANGELOG.md`; don't edit its heading or compare links.

## Architecture

All logic is in `Koha/Plugin/Com/OpenFifth/PLR.pm`; templates are in `Koha/Plugin/Com/OpenFifth/PLR/templates/` (`configure.tt`, `report.tt`).

- **Config storage**: everything lives in plugin `store_data`/`retrieve_data`. Multiple reports are a JSON-encoded array under `reports_config`, each `{authority_code, authority_name, library_group_id}`. Email recipients/from, `auto_send_enabled` and `send_day_of_month` are shared across all reports.
- **`configure`** reads dynamic form fields `authority_code_$i`, `authority_name_$i`, `library_group_id_$i` for `$i` in `0..report_count-1`; `library_group_id` must be numeric or is blanked.
- **`report`** (the tool entry point) dispatches on the `action` param: `generate` (preview), `download` (by `report_index` into the config array), `send`.
- **`_generate_plr_report`** is the core. It always reports the previous calendar month (`statistics` rows of type `issue`/`renew` with an ISBN). When `library_group_id` is set, both the loan query (join `library_groups` on `s.branch`) and the per-row copy-count query (on `i.homebranch`) are scoped with `lg.parent_id = ?`; otherwise both are unscoped. The two SQL variants are duplicated, so change both together. Selects use `MAX()` on non-grouped columns because Koha runs with `ONLY_FULL_GROUP_BY`. ISBN is normalised to 13 digits if it starts with `978`, otherwise 10; rows without a match are skipped.
- **Output format**: header `code|DDMMYYYY|DDMMYYYY`, rows `ISBN|issues|copies|AUTH4|itemtype`, footer `isbn_count|issue_count`. Filename is `plrdata_<DDMMYYYY>_<authority_code>.txt`.
- **Sending**: `_send_all_reports` generates and emails one MIME::Lite message per configured report to the shared recipient list. `cronjob_nightly` calls it when `auto_send_enabled` and today's day-of-month equals `send_day_of_month`. `send_plr_report` is a backwards-compat wrapper returning only the first report's result.
- **Upgrade path**: `upgrade` migrates the legacy single `authority_code`/`authority_name` keys into `reports_config`.

## Conventions

- Don't put named individuals' email addresses (or other personal data) in code, docs, examples, defaults or CI config; use group aliases such as `hosting@openfifth.co.uk`.
- `README.md` and `MIGRATION.md` still describe the single-authority configuration; the code is multi-report with library-group scoping.
- Commit messages are conventional-commit style (`feat:`, `fix:`, `chore:`); there is no Bugzilla workflow here, unlike Koha core.

# Koha PLR Reports Plugin

A Koha plugin for generating and submitting Public Lending Right (PLR) reports to the British Library.

## Features

- **Automated Report Generation**: Generates PLR reports based on loan statistics (issues and renewals) from the previous month
- **Configurable Settings**: Easy configuration of authority code, authority name, email recipients, and sending schedule
- **Manual or Automated Sending**: Reports can be generated and sent manually through the UI, or automatically via cronjob
- **Report Preview**: View and download reports before sending
- **PLR Standard Format**: Follows the standard PLR report format required by the British Library

## Installation

1. Download the latest release (`.kpz` file)
2. In Koha, go to: Home > Tools > Plugins
3. Click "Upload plugin"
4. Select the downloaded `.kpz` file
5. Click "Upload"

## Configuration

After installation, configure the plugin:

1. Go to: Home > Tools > Plugins
2. Find "PLR Reports" and click "Configure"
3. Fill in the required fields:
   - **Authority Code**: Your library's PLR authority code
   - **Authority Name**: Your library's full name
   - **Email Recipients**: Comma-separated list of recipients (e.g., Joanne.Hawkins@bl.uk,plrlibrary@bl.uk)
   - **Email From**: Sender email address
   - **Enable Automatic Sending**: Check to enable automatic monthly sending
   - **Send Day of Month**: Day of month to automatically send (typically 1st)
4. Click "Save configuration"

## Usage

### Manual Report Generation

1. Go to: Home > Tools > Plugins
2. Find "PLR Reports" and click "Run tool"
3. Click "Generate Report" to create a report for the previous month
4. Review the report preview and statistics
5. Click "Download Report" to save locally, or "Send Report via Email" to submit

### Automated Sending

When automatic sending is enabled in configuration, the plugin will:
- Run daily via the `cronjob_nightly` hook
- Check if today matches the configured send day
- Automatically generate and send the report if it's the correct day

## Report Format

The plugin generates reports in the standard PLR format:

```
Header: AuthorityCode|StartDate|EndDate
Data: ISBN|IssueCount|CopyCount|AuthorCode|ItemType
...
Footer: TotalISBNs|TotalIssues
```

### Data Collection

The report includes:
- All issues and renewals from the previous calendar month
- Only items with ISBNs
- ISBN (10 or 13 digit), issue count, copy count, author code (first 4 letters), and item type
- Summary statistics

## Requirements

- Koha 22.05 or later
- Perl modules: MIME::Lite, DateTime

## Support

For issues, questions, or feature requests, please contact OpenFifth at hosting@openfifth.co.uk

## License

This plugin is free software; you can redistribute it and/or modify it under the same terms as Koha.

## Author

OpenFifth - https://openfifth.co.uk

## Changelog

### Version 1.0.0 (2026-02-16)
- Initial release
- Automated PLR report generation
- Configurable email settings and schedule
- Manual report generation and sending via UI
- Report preview and download functionality

# Migration from Shell Script to Plugin

This document explains how the original `get_plr_usage.sh` script functionality has been converted to the Koha PLR Plugin.

## Script vs Plugin Mapping

### Original Script Components

| Script Feature | Plugin Equivalent | Notes |
|---------------|-------------------|-------|
| SQL query for statistics | `generate_plr_report()` method | Same logic, using Koha's DBI |
| Date calculations | DateTime module | Previous month calculation |
| ISBN extraction (10/13 digit) | `generate_plr_report()` method | Same regex logic |
| Copy count query | Embedded in report generation | Uses prepared statements |
| File output to /tmp | In-memory generation | No temp files needed |
| Email with uuencode | MIME::Lite attachment | Modern email handling |
| Sendmail execution | MIME::Lite->send() | Uses Koha's mail config |

### Configuration Migration

Replace these script placeholders with plugin configuration values:

| Script Placeholder | Plugin Configuration Field | Example |
|-------------------|---------------------------|---------|
| `<database_name>` | Automatic (uses Koha DB) | N/A |
| `<authority_code>` | Authority Code | "2345" |
| `<Authority Name>` | Authority Name | "Example Library" |
| `<filename>` | Auto-generated | "plrdata_16022026.txt" |
| Email recipients | Email Recipients | "Joanne.Hawkins@bl.uk,..." |
| Sender email | Email From | "mail@openfifth.co.uk" |

### Cron Script Replacement

**Old approach:**
```bash
# Crontab entry
0 1 1 * * /path/to/get_plr_usage.sh
```

**New approach:**
1. Enable "Automatic Sending" in plugin configuration
2. Set "Send Day of Month" to 1
3. Koha's `cronjob_nightly` hook runs the plugin automatically

No separate cron entry needed - uses Koha's existing cronjob infrastructure.

## SQL Query Comparison

### Original Script SQL
```sql
SELECT COUNT(s.itemnumber) AS COUNT,
       bi.isbn AS ISBN,
       UPPER(SUBSTRING(b.author,1,4)) AS AUTHOR,
       s.itemtype AS ITEMTYPE,
       s.itemnumber AS ITEMNUMBER,
       i.biblionumber AS BIBLIONUMBER
FROM statistics s
LEFT JOIN items i ON (s.itemnumber = i.itemnumber)
LEFT JOIN biblioitems bi ON (i.biblionumber = bi.biblionumber)
LEFT JOIN biblio b ON (i.biblionumber = b.biblionumber)
WHERE s.datetime >= concat(date_format(LAST_DAY(now() - interval 1 month),'%Y-%m-'),'01')
  AND s.datetime <= concat(date_format(LAST_DAY(now()),'%Y-%m-'),'01')
  AND s.type IN ('issue', 'renew')
  AND bi.isbn IS NOT NULL
GROUP BY bi.isbn
ORDER BY bi.isbn;
```

### Plugin SQL
```perl
SELECT COUNT(s.itemnumber) AS COUNT,
       bi.isbn AS ISBN,
       UPPER(SUBSTRING(b.author,1,4)) AS AUTHOR,
       s.itemtype AS ITEMTYPE,
       s.itemnumber AS ITEMNUMBER,
       i.biblionumber AS BIBLIONUMBER
FROM statistics s
LEFT JOIN items i ON (s.itemnumber = i.itemnumber)
LEFT JOIN biblioitems bi ON (i.biblionumber = bi.biblionumber)
LEFT JOIN biblio b ON (i.biblionumber = b.biblionumber)
WHERE s.datetime >= ?
  AND s.datetime < ?
  AND s.type IN ('issue', 'renew')
  AND bi.isbn IS NOT NULL
GROUP BY bi.isbn
ORDER BY bi.isbn
```

**Changes:**
- Uses parameterized queries (safer)
- Date calculation in Perl (cleaner)
- Same output format

## Output Format

Both the script and plugin generate identical output format:

```
AUTHORITY_CODE|START_DATE|END_DATE
ISBN|ISSUE_COUNT|COPY_COUNT|AUTHOR_CODE|ITEMTYPE
...
TOTAL_ISBNS|TOTAL_ISSUES
```

Example:
```
2345|01012026|31012026
9780123456789|5|3|SMIT|BOOK
9780987654321|2|1|JONE|BOOK
2|7
```

## Benefits of Plugin vs Script

### Advantages

1. **No manual configuration editing** - UI-based configuration
2. **Integrated with Koha** - Appears in Tools > Plugins menu
3. **Report preview** - See report before sending
4. **Error handling** - Better error messages
5. **No shell dependencies** - Pure Perl implementation
6. **Version control** - Plugin versioning built-in
7. **Easy updates** - Upload new .kpz file to upgrade

### What You Gain

- **Web UI access**: Generate reports on-demand from Koha interface
- **Manual control**: Generate, preview, download before sending
- **Better scheduling**: Uses Koha's cronjob hooks
- **Proper error logging**: Errors visible in Koha logs
- **Multi-site support**: Configure per-instance via UI

## Installation Steps

1. **Build the plugin:**
   ```bash
   cd /home/martin/Projects/koha-plugins/koha-plugin-plr
   ./build.sh
   ```

2. **Upload to Koha:**
   - Go to Tools > Plugins
   - Click "Upload plugin"
   - Select `koha-plugin-plr-v1.0.0.kpz`
   - Click "Upload"

3. **Configure:**
   - Click "Configure" on the PLR Reports plugin
   - Enter your authority code, authority name, email settings
   - Enable automatic sending if desired
   - Save configuration

4. **Remove old cron entry:**
   ```bash
   # Remove or comment out the old crontab entry
   crontab -e
   # Remove: 0 1 1 * * /path/to/get_plr_usage.sh
   ```

5. **Test:**
   - Click "Run tool" on the PLR Reports plugin
   - Click "Generate Report"
   - Verify the report content
   - Click "Send Report via Email" to test sending

## Troubleshooting

### Report Generation Issues

**Problem:** No data in report
- Check that there are loans in the previous month
- Verify items have ISBNs in biblioitems table
- Check Koha's statistics table has 'issue' and 'renew' entries

**Problem:** Email not sending
- Verify email configuration in plugin settings
- Check Koha's email configuration (koha-conf.xml)
- Check system logs for sendmail/SMTP errors

**Problem:** Automatic sending not working
- Ensure "Enable Automatic Sending" is checked
- Verify `cronjob_nightly.pl` is running in crontab
- Check Koha logs for plugin errors

### Getting Help

Check the Koha logs for plugin-related errors:
```bash
tail -f /var/log/koha/[instance]/intranet-error.log | grep PLR
```

Contact OpenFifth support: hosting@openfifth.co.uk

# PLR Plugin Quick Start Guide

Get started with the Koha PLR Reports Plugin in 5 minutes.

## 1. Install the Plugin

The plugin package has already been built: `koha-plugin-plr-v1.0.0.kpz`

In Koha:
1. Navigate to: **Home > Tools > Plugins**
2. Click **"Upload plugin"**
3. Select `koha-plugin-plr-v1.0.0.kpz`
4. Click **"Upload"**

## 2. Configure the Plugin

After installation, find "PLR Reports" in the plugins list:

1. Click **"Configure"** on the PLR Reports plugin
2. Fill in these fields (based on your original script):

   ```
   Authority Code: [Your code from the script]
   Authority Name: [Your library name from the script]

   Email Recipients: Joanne.Hawkins@bl.uk,hosting@openfifth.co.uk,plrlibrary@bl.uk
   Email From: mail@openfifth.co.uk

   ☐ Enable Automatic Sending (optional - check to enable)
   Send Day of Month: 1
   ```

3. Click **"Save configuration"**

## 3. Generate Your First Report

Test the plugin:

1. Click **"Run tool"** on the PLR Reports plugin
2. Click **"Generate Report"**
3. Review the report preview:
   - Check the date range (should be previous month)
   - Verify ISBN count and issue count
   - Preview the report content

4. **Test sending:**
   - Click **"Send Report via Email"** (only if you want to test the actual email)
   - Or click **"Download Report"** to save locally

## 4. Enable Automatic Monthly Sending (Optional)

To replace your old cron script completely:

1. Go back to **Configure**
2. Check **"Enable Automatic Sending"**
3. Set **"Send Day of Month"** to **1** (or your preferred day)
4. Click **"Save configuration"**

The plugin will automatically:
- Run via Koha's `cronjob_nightly` hook
- Generate and send reports on the 1st of each month
- Log results to Koha logs

## 5. Remove Old Cron Job

Once the plugin is working:

```bash
# Edit your crontab
crontab -e

# Remove or comment out the old line:
# 0 1 1 * * /home/martin/Projects/scripts/koha/Custom/get_plr_usage.sh
```

## Pre-populated Defaults

The plugin comes pre-configured with these defaults from your original script:

- **Email Recipients**: Joanne.Hawkins@bl.uk,hosting@openfifth.co.uk,plrlibrary@bl.uk
- **Sender Email**: mail@openfifth.co.uk
- **Send Day**: 1st of each month
- **Report Format**: Identical to original script output

You only need to add:
- Your authority code
- Your authority name

## Report Format

The plugin generates reports in exactly the same format as your original script:

```
AUTHORITY_CODE|START_DATE|END_DATE
ISBN|ISSUE_COUNT|COPY_COUNT|AUTHOR_CODE|ITEMTYPE
ISBN|ISSUE_COUNT|COPY_COUNT|AUTHOR_CODE|ITEMTYPE
...
TOTAL_ISBNS|TOTAL_ISSUES
```

## Key Features

✅ **One-click installation** - Upload and configure via web UI
✅ **Manual report generation** - Generate reports on-demand
✅ **Report preview** - See data before sending
✅ **Automatic sending** - Schedule monthly reports
✅ **Download reports** - Save reports locally
✅ **Same format** - Identical output to original script

## Troubleshooting

### No data in report?
- Check that there are loans in the previous month
- Verify items have ISBNs in the database
- Look in Tools > Reports to run a test query

### Email not sending?
- Verify email settings in plugin configuration
- Check Koha's email configuration (koha-conf.xml)
- Check `/var/log/koha/[instance]/intranet-error.log`

### Plugin not appearing?
- Make sure plugins are enabled in koha-conf.xml
- Check that `<enable_plugins>1</enable_plugins>` is set
- Restart Koha services after enabling

## Need Help?

- **Documentation**: See README.md for detailed information
- **Migration Guide**: See MIGRATION.md for script-to-plugin mapping
- **Support**: Contact hosting@openfifth.co.uk

---

**Next Steps:**
1. Install the plugin ✓
2. Configure settings ✓
3. Generate a test report ✓
4. Enable automatic sending ✓
5. Remove old cron job ✓

That's it! Your PLR reporting is now fully automated through Koha.

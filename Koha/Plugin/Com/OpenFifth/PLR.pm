package Koha::Plugin::Com::OpenFifth::PLR;

use Modern::Perl;

use base qw(Koha::Plugins::Base);

use C4::Context;
use Koha::DateUtils qw(dt_from_string output_pref);
use MIME::Lite;
use DateTime;
use File::Spec;
use JSON qw(encode_json decode_json);

our $VERSION = '1.2.0';
our $MINIMUM_VERSION = "22.05.00.000";

our $metadata = {
    name            => 'PLR Reports',
    author          => 'OpenFifth',
    description     => 'Public Lending Right (PLR) reporting plugin for automated submission to the British Library',
    date_authored   => '2026-02-16',
    date_updated    => '2026-03-03',
    minimum_version => $MINIMUM_VERSION,
    maximum_version => undef,
    version         => $VERSION,
};

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    my $self = $class->SUPER::new($args);

    return $self;
}

sub install {
    my ( $self, $args ) = @_;

    $self->store_data({
        reports_config    => encode_json([]),
        email_recipients  => 'Joanne.Hawkins@bl.uk,hosting@openfifth.co.uk,plrlibrary@bl.uk',
        email_from        => 'mail@openfifth.co.uk',
        auto_send_enabled => 0,
        send_day_of_month => 1,
    });

    return 1;
}

sub upgrade {
    my ( $self, $args ) = @_;

    my $existing = $self->retrieve_data('reports_config');
    my $old_code = $self->retrieve_data('authority_code');

    if ( !$existing && $old_code ) {
        my $old_name = $self->retrieve_data('authority_name') // '';
        $self->store_data({
            reports_config => encode_json([{
                authority_code   => $old_code,
                authority_name   => $old_name,
                library_group_id => '',
            }])
        });
    }
    elsif ( !$existing ) {
        $self->store_data({ reports_config => encode_json([]) });
    }

    return 1;
}

sub uninstall {
    my ( $self, $args ) = @_;
    return 1;
}

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template({ file => 'templates/configure.tt' });

        $template->param(
            reports           => $self->_get_reports_config(),
            email_recipients  => $self->retrieve_data('email_recipients'),
            email_from        => $self->retrieve_data('email_from'),
            auto_send_enabled => $self->retrieve_data('auto_send_enabled'),
            send_day_of_month => $self->retrieve_data('send_day_of_month'),
        );

        $self->output_html( $template->output() );
    }
    else {
        my $report_count = $cgi->param('report_count') || 0;
        my @reports;

        for my $i ( 0 .. $report_count - 1 ) {
            my $code     = $cgi->param("authority_code_$i")   // '';
            my $name     = $cgi->param("authority_name_$i")   // '';
            my $group_id = $cgi->param("library_group_id_$i") // '';

            # Validate group_id is numeric or blank
            $group_id = '' unless $group_id =~ /^\d+$/;

            push @reports, {
                authority_code   => $code,
                authority_name   => $name,
                library_group_id => $group_id,
            };
        }

        $self->store_data({
            reports_config    => encode_json(\@reports),
            email_recipients  => $cgi->param('email_recipients'),
            email_from        => $cgi->param('email_from'),
            auto_send_enabled => $cgi->param('auto_send_enabled') ? 1 : 0,
            send_day_of_month => $cgi->param('send_day_of_month'),
        });
        $self->go_home();
    }
}

sub report {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $action = $cgi->param('action') || '';

    if ( $action eq 'generate' ) {
        my $reports_data = $self->_generate_all_reports();
        my $template = $self->get_template({ file => 'templates/report.tt' });
        $template->param(
            reports_generated => 1,
            reports_data      => $reports_data,
        );
        $self->output_html( $template->output() );
    }
    elsif ( $action eq 'download' ) {
        my $report_index = $cgi->param('report_index') // 0;
        my $configs      = $self->_get_reports_config();
        my $config       = $configs->[$report_index];

        if ( $config ) {
            my $report_data = $self->_generate_plr_report($config);
            if ( $report_data ) {
                print $cgi->header(
                    -type       => 'text/plain',
                    -attachment => $report_data->{filename},
                );
                print $report_data->{content};
                return;
            }
        }

        my $template = $self->get_template({ file => 'templates/report.tt' });
        $template->param( error => 'Failed to generate report for download.' );
        $self->output_html( $template->output() );
    }
    elsif ( $action eq 'send' ) {
        my $send_results = $self->_send_all_reports();
        my $template = $self->get_template({ file => 'templates/report.tt' });
        $template->param( send_results => $send_results );
        $self->output_html( $template->output() );
    }
    else {
        my $template = $self->get_template({ file => 'templates/report.tt' });
        $self->output_html( $template->output() );
    }
}

# --- Private helpers ---

sub _get_reports_config {
    my ( $self ) = @_;
    my $json = $self->retrieve_data('reports_config') || encode_json([]);
    return decode_json($json);
}

sub _generate_plr_report {
    my ( $self, $report_config ) = @_;

    my $authority_code   = $report_config->{authority_code}   // '';
    my $authority_name   = $report_config->{authority_name}   // '';
    my $library_group_id = $report_config->{library_group_id} // '';

    unless ( $authority_code && $authority_name ) {
        warn "PLR Plugin: Authority code and name must be configured";
        return undef;
    }

    my $dbh = C4::Context->dbh;

    # Calculate date range (previous month)
    my $now        = DateTime->now();
    my $last_month = $now->clone->subtract(months => 1);

    my $start_date = $last_month->clone->set_day(1);
    my $end_date   = $last_month->clone->add(months => 1)->set_day(1);

    my $start_date_formatted = $start_date->strftime('%d%m%Y');
    my $end_date_prev        = $end_date->clone->subtract(days => 1);
    my $end_date_formatted   = $end_date_prev->strftime('%d%m%Y');

    # Build main SQL – optionally scoped to a library group
    my ( $sql, @bind );
    if ( $library_group_id ) {
        $sql = q{
            SELECT
                COUNT(s.itemnumber) AS COUNT,
                bi.isbn AS ISBN,
                UPPER(SUBSTRING(MAX(b.author),1,4)) AS AUTHOR,
                s.itemtype AS ITEMTYPE,
                MAX(s.itemnumber) AS ITEMNUMBER,
                MAX(i.biblionumber) AS BIBLIONUMBER
            FROM statistics s
            LEFT JOIN items i ON (s.itemnumber = i.itemnumber)
            LEFT JOIN library_groups lg ON (s.branch = lg.branchcode)
            LEFT JOIN biblioitems bi ON (i.biblionumber = bi.biblionumber)
            LEFT JOIN biblio b ON (i.biblionumber = b.biblionumber)
            WHERE s.datetime >= ?
                AND s.datetime < ?
                AND s.type IN ('issue', 'renew')
                AND bi.isbn IS NOT NULL
                AND lg.parent_id = ?
            GROUP BY bi.isbn, s.itemtype
            ORDER BY bi.isbn, s.itemtype
        };
        @bind = ( $start_date->ymd, $end_date->ymd, $library_group_id );
    }
    else {
        $sql = q{
            SELECT
                COUNT(s.itemnumber) AS COUNT,
                bi.isbn AS ISBN,
                UPPER(SUBSTRING(MAX(b.author),1,4)) AS AUTHOR,
                s.itemtype AS ITEMTYPE,
                MAX(s.itemnumber) AS ITEMNUMBER,
                MAX(i.biblionumber) AS BIBLIONUMBER
            FROM statistics s
            LEFT JOIN items i ON (s.itemnumber = i.itemnumber)
            LEFT JOIN biblioitems bi ON (i.biblionumber = bi.biblionumber)
            LEFT JOIN biblio b ON (i.biblionumber = b.biblionumber)
            WHERE s.datetime >= ?
                AND s.datetime < ?
                AND s.type IN ('issue', 'renew')
                AND bi.isbn IS NOT NULL
            GROUP BY bi.isbn, s.itemtype
            ORDER BY bi.isbn, s.itemtype
        };
        @bind = ( $start_date->ymd, $end_date->ymd );
    }

    my $sth = $dbh->prepare($sql);
    $sth->execute(@bind);

    my @report_lines;
    my $isbn_count  = 0;
    my $issue_count = 0;

    # Header line
    push @report_lines, "$authority_code|$start_date_formatted|$end_date_formatted";

    while ( my $row = $sth->fetchrow_hashref ) {
        my $isbn         = $row->{ISBN};
        my $contributor  = $row->{AUTHOR};
        my $biblionumber = $row->{BIBLIONUMBER};
        my $itemtype     = $row->{ITEMTYPE};
        my $no_issues    = $row->{COUNT};

        my $real_isbn;
        if ( $isbn =~ /^978/ ) {
            ($real_isbn) = $isbn =~ /^(\d{13})/;
        }
        else {
            ($real_isbn) = $isbn =~ /^(\d{10})/;
        }

        next unless $real_isbn;

        # Copy count – also scoped to library group if set
        my ( $copy_count_sql, @copy_bind );
        if ( $library_group_id ) {
            $copy_count_sql = q{
                SELECT COUNT(i.itemnumber)
                FROM items i
                LEFT JOIN library_groups lg ON (i.homebranch = lg.branchcode)
                WHERE i.biblionumber = ?
                  AND lg.parent_id = ?
            };
            @copy_bind = ( $biblionumber, $library_group_id );
        }
        else {
            $copy_count_sql = q{
                SELECT COUNT(itemnumber)
                FROM items
                WHERE biblionumber = ?
            };
            @copy_bind = ($biblionumber);
        }

        my $copy_sth = $dbh->prepare($copy_count_sql);
        $copy_sth->execute(@copy_bind);
        my ($copy_count) = $copy_sth->fetchrow_array;

        push @report_lines, "$real_isbn|$no_issues|$copy_count|$contributor|$itemtype";
        $isbn_count++;
        $issue_count += $no_issues;
    }

    # Footer line
    push @report_lines, "$isbn_count|$issue_count";

    my $content  = join("\n", @report_lines) . "\n";
    my $today    = DateTime->now()->strftime('%d%m%Y');
    my $filename = "plrdata_${today}_${authority_code}.txt";

    return {
        content        => $content,
        filename       => $filename,
        isbn_count     => $isbn_count,
        issue_count    => $issue_count,
        start_date     => $start_date_formatted,
        end_date       => $end_date_formatted,
        authority_code => $authority_code,
        authority_name => $authority_name,
    };
}

sub _generate_all_reports {
    my ( $self ) = @_;

    my $configs = $self->_get_reports_config();
    my @results;
    my $index = 0;

    for my $config ( @$configs ) {
        my $data = $self->_generate_plr_report($config);
        if ( $data ) {
            $data->{report_index} = $index;
            push @results, $data;
        }
        $index++;
    }

    return \@results;
}

sub _send_single_report {
    my ( $self, $report_data ) = @_;

    my $email_recipients = $self->retrieve_data('email_recipients');
    my $email_from       = $self->retrieve_data('email_from');

    unless ( $email_recipients && $email_from ) {
        return {
            success        => 0,
            error          => 'Missing email configuration',
            authority_code => $report_data->{authority_code},
            authority_name => $report_data->{authority_name},
        };
    }

    my $authority_code = $report_data->{authority_code};
    my $authority_name = $report_data->{authority_name};
    my $subject        = "PLR Return for $authority_code - $authority_name";
    my $body           = "Dear PLR\n\nPlease find attached PLR return for $authority_code - $authority_name for the last period\n\n";

    my $msg = MIME::Lite->new(
        From    => $email_from,
        To      => $email_recipients,
        Subject => $subject,
        Type    => 'multipart/mixed',
    );

    $msg->attach(
        Type => 'TEXT',
        Data => $body,
    );

    $msg->attach(
        Type        => 'text/plain',
        Data        => $report_data->{content},
        Filename    => $report_data->{filename},
        Disposition => 'attachment',
    );

    eval { $msg->send };

    if ( $@ ) {
        return {
            success        => 0,
            error          => "Email send failed: $@",
            authority_code => $authority_code,
            authority_name => $authority_name,
        };
    }

    return {
        success        => 1,
        authority_code => $authority_code,
        authority_name => $authority_name,
    };
}

sub _send_all_reports {
    my ( $self ) = @_;

    my $configs = $self->_get_reports_config();
    my @results;

    for my $config ( @$configs ) {
        my $report_data = $self->_generate_plr_report($config);
        if ( !$report_data ) {
            push @results, {
                success        => 0,
                error          => 'Failed to generate report',
                authority_code => $config->{authority_code} // '',
                authority_name => $config->{authority_name} // '',
            };
            next;
        }
        push @results, $self->_send_single_report($report_data);
    }

    return \@results;
}

# Public backwards-compat wrapper
sub send_plr_report {
    my ( $self ) = @_;
    my $results = $self->_send_all_reports();
    return $results->[0] // { success => 0, error => 'No reports configured' };
}

sub cronjob_nightly {
    my ( $self ) = @_;

    my $auto_send_enabled = $self->retrieve_data('auto_send_enabled');
    my $send_day          = $self->retrieve_data('send_day_of_month');

    return unless $auto_send_enabled;

    my $today = DateTime->now()->day;

    if ( $today == $send_day ) {
        my $results = $self->_send_all_reports();
        for my $result ( @$results ) {
            if ( $result->{success} ) {
                warn "PLR Plugin: Report for $result->{authority_code} sent successfully on day $send_day";
            }
            else {
                warn "PLR Plugin: Failed to send report for $result->{authority_code}: "
                    . ( $result->{error} // 'unknown error' );
            }
        }
    }
}

1;

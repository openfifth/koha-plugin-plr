package Koha::Plugin::Com::OpenFifth::PLR;

use Modern::Perl;

use base qw(Koha::Plugins::Base);

use C4::Context;
use Koha::DateUtils qw(dt_from_string output_pref);
use MIME::Lite;
use DateTime;
use File::Spec;

our $VERSION = '1.0.0';
our $MINIMUM_VERSION = "22.05.00.000";

our $metadata = {
    name            => 'PLR Reports',
    author          => 'OpenFifth',
    description     => 'Public Lending Right (PLR) reporting plugin for automated submission to the British Library',
    date_authored   => '2026-02-16',
    date_updated    => '2026-02-16',
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

    # Set default configuration values
    $self->store_data({
        authority_code => '',
        authority_name => '',
        email_recipients => 'Joanne.Hawkins@bl.uk,hosting@openfifth.co.uk,plrlibrary@bl.uk',
        email_from => 'mail@openfifth.co.uk',
        auto_send_enabled => 0,
        send_day_of_month => 1,
    });

    return 1;
}

sub upgrade {
    my ( $self, $args ) = @_;
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
        my $template = $self->get_template({ file => 'configure.tt' });

        $template->param(
            authority_code => $self->retrieve_data('authority_code'),
            authority_name => $self->retrieve_data('authority_name'),
            email_recipients => $self->retrieve_data('email_recipients'),
            email_from => $self->retrieve_data('email_from'),
            auto_send_enabled => $self->retrieve_data('auto_send_enabled'),
            send_day_of_month => $self->retrieve_data('send_day_of_month'),
        );

        $self->output_html( $template->output() );
    }
    else {
        $self->store_data({
            authority_code => $cgi->param('authority_code'),
            authority_name => $cgi->param('authority_name'),
            email_recipients => $cgi->param('email_recipients'),
            email_from => $cgi->param('email_from'),
            auto_send_enabled => $cgi->param('auto_send_enabled') ? 1 : 0,
            send_day_of_month => $cgi->param('send_day_of_month'),
        });
        $self->go_home();
    }
}

sub tool {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $action = $cgi->param('action') || '';

    if ( $action eq 'generate' ) {
        my $report_data = $self->generate_plr_report();

        if ( $report_data ) {
            my $template = $self->get_template({ file => 'tool.tt' });
            $template->param(
                report_generated => 1,
                report_content => $report_data->{content},
                report_filename => $report_data->{filename},
                isbn_count => $report_data->{isbn_count},
                issue_count => $report_data->{issue_count},
                start_date => $report_data->{start_date},
                end_date => $report_data->{end_date},
            );
            $self->output_html( $template->output() );
        }
        else {
            my $template = $self->get_template({ file => 'tool.tt' });
            $template->param(
                error => 'Failed to generate report. Please check configuration.',
            );
            $self->output_html( $template->output() );
        }
    }
    elsif ( $action eq 'download' ) {
        my $report_data = $self->generate_plr_report();
        if ( $report_data ) {
            print $cgi->header(
                -type => 'text/plain',
                -attachment => $report_data->{filename},
            );
            print $report_data->{content};
        }
    }
    elsif ( $action eq 'send' ) {
        my $result = $self->send_plr_report();
        my $template = $self->get_template({ file => 'tool.tt' });
        $template->param(
            email_sent => $result->{success},
            email_error => $result->{error},
        );
        $self->output_html( $template->output() );
    }
    else {
        my $template = $self->get_template({ file => 'tool.tt' });
        $self->output_html( $template->output() );
    }
}

sub generate_plr_report {
    my ( $self ) = @_;

    my $authority_code = $self->retrieve_data('authority_code');
    my $authority_name = $self->retrieve_data('authority_name');

    unless ( $authority_code && $authority_name ) {
        warn "PLR Plugin: Authority code and name must be configured";
        return undef;
    }

    my $dbh = C4::Context->dbh;

    # Calculate date range (previous month)
    my $now = DateTime->now();
    my $last_month = $now->clone->subtract(months => 1);

    my $start_date = $last_month->clone->set_day(1);
    my $end_date = $last_month->clone->add(months => 1)->set_day(1);

    # Format dates for output
    my $start_date_formatted = $start_date->strftime('%d%m%Y');
    my $end_date_prev = $end_date->clone->subtract(days => 1);
    my $end_date_formatted = $end_date_prev->strftime('%d%m%Y');

    # SQL query to get PLR data
    my $sql = q{
        SELECT
            COUNT(s.itemnumber) AS COUNT,
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
    };

    my $sth = $dbh->prepare($sql);
    $sth->execute($start_date->ymd, $end_date->ymd);

    my @report_lines;
    my $isbn_count = 0;
    my $issue_count = 0;

    # Header line
    push @report_lines, "$authority_code|$start_date_formatted|$end_date_formatted";

    # Process each ISBN
    while ( my $row = $sth->fetchrow_hashref ) {
        my $isbn = $row->{ISBN};
        my $contributor = $row->{AUTHOR};
        my $biblionumber = $row->{BIBLIONUMBER};
        my $itemtype = $row->{ITEMTYPE};
        my $no_issues = $row->{COUNT};

        # Extract real ISBN (13 or 10 digit)
        my $real_isbn;
        if ( $isbn =~ /^978/ ) {
            # 13 digit ISBN
            ($real_isbn) = $isbn =~ /^(\d{13})/;
        }
        else {
            # 10 digit ISBN
            ($real_isbn) = $isbn =~ /^(\d{10})/;
        }

        next unless $real_isbn;

        # Get copy count for this biblionumber
        my $copy_count_sql = q{
            SELECT COUNT(itemnumber)
            FROM items
            WHERE biblionumber = ?
        };
        my $copy_sth = $dbh->prepare($copy_count_sql);
        $copy_sth->execute($biblionumber);
        my ($copy_count) = $copy_sth->fetchrow_array;

        # Build data line
        push @report_lines, "$real_isbn|$no_issues|$copy_count|$contributor|$itemtype";

        $isbn_count++;
        $issue_count += $no_issues;
    }

    # Footer line
    push @report_lines, "$isbn_count|$issue_count";

    my $content = join("\n", @report_lines) . "\n";
    my $today = DateTime->now()->strftime('%d%m%Y');
    my $filename = "plrdata_${today}.txt";

    return {
        content => $content,
        filename => $filename,
        isbn_count => $isbn_count,
        issue_count => $issue_count,
        start_date => $start_date_formatted,
        end_date => $end_date_formatted,
    };
}

sub send_plr_report {
    my ( $self ) = @_;

    my $authority_code = $self->retrieve_data('authority_code');
    my $authority_name = $self->retrieve_data('authority_name');
    my $email_recipients = $self->retrieve_data('email_recipients');
    my $email_from = $self->retrieve_data('email_from');

    unless ( $authority_code && $authority_name && $email_recipients && $email_from ) {
        return { success => 0, error => 'Missing required configuration' };
    }

    my $report_data = $self->generate_plr_report();
    unless ( $report_data ) {
        return { success => 0, error => 'Failed to generate report' };
    }

    # Create email
    my $subject = "PLR Return for $authority_code - $authority_name";
    my $body = "Dear PLR\n\nPlease find attached PLR return for $authority_code - $authority_name for the last period\n\n";

    my $msg = MIME::Lite->new(
        From    => $email_from,
        To      => $email_recipients,
        Subject => $subject,
        Type    => 'multipart/mixed',
    );

    # Add body
    $msg->attach(
        Type => 'TEXT',
        Data => $body,
    );

    # Add attachment
    $msg->attach(
        Type        => 'text/plain',
        Data        => $report_data->{content},
        Filename    => $report_data->{filename},
        Disposition => 'attachment',
    );

    # Send email
    eval {
        $msg->send;
    };

    if ( $@ ) {
        return { success => 0, error => "Email send failed: $@" };
    }

    return { success => 1 };
}

sub cronjob_nightly {
    my ( $self ) = @_;

    my $auto_send_enabled = $self->retrieve_data('auto_send_enabled');
    my $send_day = $self->retrieve_data('send_day_of_month');

    return unless $auto_send_enabled;

    my $today = DateTime->now()->day;

    if ( $today == $send_day ) {
        my $result = $self->send_plr_report();
        if ( $result->{success} ) {
            warn "PLR Plugin: Report sent successfully on day $send_day";
        }
        else {
            warn "PLR Plugin: Failed to send report: " . $result->{error};
        }
    }
}

1;

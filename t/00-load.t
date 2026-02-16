#!/usr/bin/perl

use Modern::Perl;
use Test::More tests => 2;

BEGIN {
    use_ok('Koha::Plugin::Com::OpenFifth::PLR');
}

my $plugin = Koha::Plugin::Com::OpenFifth::PLR->new({ enable_plugins => 1 });
isa_ok($plugin, 'Koha::Plugin::Com::OpenFifth::PLR');

done_testing();

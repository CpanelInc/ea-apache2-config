#!/usr/local/cpanel/3rdparty/bin/perl
# cpanel - 080-phpconf.pl                         Copyright(c) 2015 cPanel, Inc.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use strict;
use Cpanel::Imports;
use Cpanel::DataStore           ();
use Cpanel::ConfigFiles::Apache ();
use Cpanel::Lang::PHP::Settings ();

my $php  = Cpanel::Lang::PHP::Settings->new();
my @phps = @{ $php->php_get_installed_versions() };
if ( !@phps ) {
    print locale->maketext("There are currently no PHPs installed.") . "\n";
    exit;
}

my $apacheconf = Cpanel::ConfigFiles::Apache->new();
my $yaml       = Cpanel::DataStore::fetch_ref( $apacheconf->file_conf_php_conf() . '.yaml' );

my %php_settings = ( dryrun => 0 );
for my $ver (@phps) {
    $php_settings{$ver} = $yaml->{$ver} || 'cgi';
}

$php_settings{version} = $yaml->{'phpversion'} || $phps[-1];

$php->php_set_system_default_version(%php_settings) || log->die( $php->error() );

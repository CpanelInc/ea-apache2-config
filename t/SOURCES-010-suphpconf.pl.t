#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - t/SOURCES-010-suphpconf.pl.t              Copyright 2017 cPanel, Inc.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use strict;
use warnings;
use FindBin;
use Test::More;
use Test::NoWarnings;
use Test::Trap;
use File::Temp;
use File::Slurp;
use File::Path::Tiny ();

use Cpanel::SysPkgs::SCL ();

if ( !-e '/usr/local/bin/ea_convert_php_ini' ) {
    diag "Testing with no /usr/local/bin/ea_convert_php_ini\n";
    plan tests => 3 + 1;
    require_ok "$FindBin::Bin/../SOURCES/010-suphpconf.pl";

    my $dir = File::Temp->newdir();
    no warnings "once";
    local $suphpconf::suphpconf = "$dir/suphp.conf";

    trap { suphpconf::run() };
    is( $trap->stdout, "Nothing to do ($suphpconf::suphpconf does not exist)\n", "no suphp.conf has expected output" );

    write_file( $suphpconf::suphpconf, "; oh hai" );
    trap { suphpconf::run() };
    is( $trap->stderr, "Unable to update /etc/suphp.conf without the ea-cpanel-tools package installed.\n", "missing ea_convert_php_ini does expected warning" );

    exit(0);
}

diag "Testing w/ /usr/local/bin/ea_convert_php_ini in place\n";
plan tests => 18 + 1;

require_ok "$FindBin::Bin/../SOURCES/010-suphpconf.pl";

{
    my $dir              = File::Temp->newdir();
    my @get_scl_versions = qw(ea-php42 alt-php23);
    no warnings "redefine";
    local *Cpanel::SysPkgs::SCL::get_scl_versions = sub { return \@get_scl_versions };
    local *Cpanel::SysPkgs::SCL::get_scl_prefix   = sub { return "$dir/$_[0]"; };

    no warnings "once";
    local $suphpconf::suphpconf = "$dir/suphp.conf";

    trap { suphpconf::run() };
    is( $trap->stdout, "Nothing to do ($suphpconf::suphpconf does not exist)\n", "no suphp.conf has expected output" );

    # w/ no handlers
    write_file( $suphpconf::suphpconf, "; oh hai" );
    File::Path::Tiny::mk("$dir/ea-php42/root/usr/bin");
    write_file( "$dir/ea-php42/root/usr/bin/php-cgi", "# oh hai" );
    chmod 755, "$dir/ea-php42/root/usr/bin/php-cgi";
    trap { suphpconf::run() };

    like $trap->stdout, qr/Adding entry for “ea-php42” …/s,  "no handlers outputs adds 1";
    like $trap->stdout, qr/Adding entry for “alt-php23” …/s, "no handlers outputs adds 2";

    like $trap->stderr, qr{alt-php23/root/usr/bin/php-cgi is not executable, please rectify}, "missing binary does warning";
    isnt $trap->stderr, qr{ea-php54/root/usr/bin/php-cgi is not executable, please rectify},  "existing binary does not do warning";

    # w/ handlers that need updating
    my $handlers = qq{application/x-httpd-ea-php54 = "php:/opt/cpanel/ea-php54/root/usr/bin/php-cgi"\n};
    $handlers .= qq{application/x-httpd-ea-php42 = "php:/opt/cpanel/ea-php42/root/usr/bin/php-cgi"\n};

    write_file( $suphpconf::suphpconf, "; oh hai\n[handlers]\n$handlers" );
    trap { suphpconf::run() };

    like $trap->stdout, qr/Ignoring current entry for “ea-php54” …/,            "entries no longer on system are ignored";
    like $trap->stdout, qr/Ensuring current entry for “ea-php42” is correct …/, "current entries are updated";
    like $trap->stdout, qr/Adding entry for “alt-php23” …/,                     "new entries are added";

    my @suphpconf = read_file($suphpconf::suphpconf);
    ok grep( m{application/x-httpd-ea-php54},  @suphpconf ), "old entry is left in file";
    ok grep( m{application/x-httpd-ea-php42},  @suphpconf ), "current entry is written to file";
    ok grep( m{application/x-httpd-alt-php23}, @suphpconf ), "new entry is written to file";

    # w/ handlers that do not need updating
    trap { suphpconf::run() };

    like $trap->stdout, qr/Ignoring current entry for “ea-php54” …/,             "handlers are already ok: entries no longer on system are ignored";
    like $trap->stdout, qr/Ensuring current entry for “ea-php42” is correct …/,  "handlers are already ok: current entries are updated - 1";
    like $trap->stdout, qr/Ensuring current entry for “alt-php23” is correct …/, "handlers are already ok: current entries are updated - 2";

    @suphpconf = read_file($suphpconf::suphpconf);
    ok grep( m{application/x-httpd-ea-php54},  @suphpconf ), "handlers are already ok: old entry is left in file";
    ok grep( m{application/x-httpd-ea-php42},  @suphpconf ), "handlers are already ok: current entry is written to file - 1";
    ok grep( m{application/x-httpd-alt-php23}, @suphpconf ), "handlers are already ok: current entry is written to file - 2";
}

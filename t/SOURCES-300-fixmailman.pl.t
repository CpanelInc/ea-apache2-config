#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - t/SOURCES-300-fixmailman.pl.t          Copyright(c) 2016 cPanel, Inc.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

package t::SOURCES::fixmailman;

use strict;
use warnings;
use parent qw( Test::Class );
use FindBin;
use Test::More;
use Test::NoWarnings;

sub module_compiles : Test(1) {
    require_ok "$FindBin::Bin/../SOURCES/300-fixmailman.pl";
}

sub test_fix_list_dirs : Test(3) {
    my $self = shift;
    my $script;

    no warnings qw( redefine once );
    local *Cpanel::SafeRun::Simple::saferun = sub { $script = shift; return 1 };

    use warnings qw( redefine once );
    ok( ea_apache24_config_runtime::SOURCES::300_fixmailman::fix_list_dirs(), q{fix_list_dirs: Of course we always assumes success} );
    ok( $script,                                                              q{fix_list_dirs: Called the saferun command to do *something*, but not sure what yet} );
    is( $script, '/usr/local/cpanel/scripts/fixmailman', q{fix_list_dirs: Correct script called to fix mailing list archive directories} );

    return 1;
}

sub test_fix_rpm_dirs : Test(2) {
    my $self     = shift;
    my $setperms = 0;

    no warnings qw( redefine once );
    local *Cpanel::Mailman::Perms::set_perms = sub { $setperms = 1; return 1 };

    use warnings qw( redefine once );
    ok( ea_apache24_config_runtime::SOURCES::300_fixmailman::fix_rpm_dirs(), q{fix_rpm_dirs: We assume success baby!} );
    ok( $setperms,                                                           q{fix_rpm_dirs: Script attempted to fix the RPM directories} );

    return 1;
}

unless ( caller() ) {
    my $test = __PACKAGE__->new();
    plan tests => $test->expected_tests(+1);
    $test->runtests();
}


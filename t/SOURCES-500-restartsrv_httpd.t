#!/usr/local/cpanel/3rdparty/bin/perl
# cpanel - SOURCES-500-restartsrv_httpd.t       Copyright(c) 2023 cPanel, L.L.C.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use strict;
use warnings;

use FindBin;
my $script = "$FindBin::Bin/../SOURCES/500-restartsrv_httpd";

our $current_system = sub { goto &Test::Mock::Cmd::orig_system; };
use Test::Mock::Cmd 'system' => sub { $current_system->(@_) };

use Test::More tests => 13;
use Test::FailWarnings;

use File::Temp;
my $dir = File::Temp->newdir();

use File::Slurp;
write_file( "$dir/exists-without-pkg",     "ea-apache24-config" );
write_file( "$dir/exists-with-pkg",        "ea-apache24" );
write_file( "$dir/exists-with-pkg-fcgid",  "ea-apache24-mod_fcgid" );
write_file( "$dir/exists-with-pkg-anymod", "ea-apache24-mod_derp" );

ok( -x $script, 'SOURCES/500-restartsrv_httpd is executable' );
require_ok($script);

is( _run(),                                         1, "no args does soft restart" );
is( _run("--pkg_list"),                             1, "--pkg_list undef does soft restart" );
is( _run("--pkg_list="),                            1, "--pkg_list empty does soft restart" );
is( _run("--pkg_list=$dir/no.exists"),              1, "--pkg_list w/ non-existent file  does soft restart" );
is( _run("--pkg_list=$dir/exists-without-pkg"),     1, "--pkg_list w/out pkg in list does soft restart" );
is( _run("--pkg_list=$dir/exists-with-pkg"),        2, "--pkg_list w/ apache pkg in list does hard restart" );
is( _run("--pkg_list=$dir/exists-with-pkg-fcgid"),  2, "--pkg_list w/ fcgid pkg in list does hard restart" );
is( _run("--pkg_list=$dir/exists-with-pkg-anymod"), 2, "--pkg_list w/ any httpd module pkg in list does hard restart" );

{
    local $0 = "whatevs/100-glibc-restartsrv_httpd";
    is( _run(), 2, "glibc symlink will trigger hard restart" );

    local $ea_apache24_config_runtime::SOURCES::restartsrv_httpd::disable_flag_file = "$dir/ea4-disable-500-restartsrv_httpd-for-glibc";
    write_file( $ea_apache24_config_runtime::SOURCES::restartsrv_httpd::disable_flag_file, '' );
    is( _run(), 0, 'glibc symlink exits without restarting apache if disable touchfile is in place' );
}

{
    local $ea_apache24_config_runtime::SOURCES::restartsrv_httpd::disable_flag_file = "$dir/ea4-disable-500-restartsrv_httpd-for-glibc";
    write_file( $ea_apache24_config_runtime::SOURCES::restartsrv_httpd::disable_flag_file, '' );
    is( _run(), 1, 'disable touchfile does not prevent apache restart unless it is called through the glibc symlink' );
}

sub _run {
    my @args = @_;
    my $sys  = 0;
    local $current_system = sub { $sys++ };
    ea_apache24_config_runtime::SOURCES::restartsrv_httpd::run(@args);
    return $sys;
}


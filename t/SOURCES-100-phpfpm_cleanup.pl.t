#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - t/SOURCES-100-phpfpm_cleanup.pl.t       Copyright 2021 cPanel, L.L.C.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

## no critic qw(TestingAndDebugging::RequireUseStrict TestingAndDebugging::RequireUseWarnings)
use Test::Spec;    # automatically turns on strict and warnings

use Test::MockModule ();
use Capture::Tiny 'capture_merged';

use Test::MockFile qw< nostrict >;

use FindBin ();
require "$FindBin::Bin/../SOURCES/100-phpfpm_cleanup.pl";
$INC{"unihook/phpfpm_clean.pm"} = "$FindBin::Bin/../SOURCES/100-phpfpm_cleanup.pl";

our ( $module, $pkglst, $restart_called, $restart, $users, $rebuild_files, $phpcnf );

describe "PHP-FPM cleanup universal hook" => sub {
    it "should fail if argument is bad" => sub {
        my $pkglst = Test::MockFile->file("/tmp/trxn.list");
        _run_trap();
        like $trap->die, qr{Found path to packages “/tmp/trxn\.list” but could not read from it};
    };

    it "should do nothing if the PHP-FPM package in question is being installed" => sub {
        local $module = Test::MockModule->new('Cpanel::PackMan')->redefine( pkg_hr => sub { { version_installed => 42 } } );
        local $pkglst = Test::MockFile->file( "/tmp/trxn.list", "ea-php99-php-fpm\n" );
        _run_trap();
        like $trap->{stdout}, qr/\[ea-php99-php-fpm\] No need to clean user files since we are installing/;
    };

    describe "\b, when PHP-FPM package is being removed," => sub {
        around {
            local $users = Test::MockModule->new("unihook::phpfpm_clean")->redefine( get_users_on_fpm_version => sub { [qw(joe mama)] } )->redefine( disable_all_fpm_users_for_version => sub { } );

            local $rebuild_files  = Test::MockModule->new("Cpanel::PHPFPM")->redefine( rebuild_files => sub { 1 } );
            local $module         = Test::MockModule->new('Cpanel::PackMan')->redefine( pkg_hr => sub { } );
            local $pkglst         = Test::MockFile->file( "/tmp/trxn.list", "ea-php99-php-fpm\n" );
            local $restart_called = 0;
            local $restart        = Test::MockModule->new("Cpanel::HttpUtils::ApRestart::BgSafe")->redefine( restart => sub { $restart_called++ } );
            local $phpcnf         = Test::MockModule->new("Cpanel::PHP::Config")->redefine( get_php_config_for_users => sub { { x => 42 } } );
            yield;
        };

        describe "when no users are on that version" => sub {
            around {
                local $users  = Test::MockModule->new("unihook::phpfpm_clean")->redefine( get_users_on_fpm_version => sub { [] } )->redefine( disable_all_fpm_users_for_version => sub { } );
                local $phpcnf = Test::MockModule->new("Cpanel::PHP::Config")->redefine( get_php_config_for_users => sub { {} } );
                yield;
            };

            it "should skip FPM rebuild" => sub {
                _run_trap();
                like $trap->{stdout}, qr/No domains were on ea-php99-php-fpm/;
            };

            it "should restart apache" => sub {
                _run_trap();
                is $restart_called, 1;
            };
        };

        describe "when there are users on that version" => sub {
            it "should do FPM rebuild" => sub {
                _run_trap();
                like $trap->{stdout}, qr/All domains that were on ea-php99-php-fpm/;
            };

            it "should restart apache" => sub {
                _run_trap();
                is $restart_called, 1;
            };
        };

        describe "when there is a problem w/ rebuilding" => sub {
            around {
                local $rebuild_files = Test::MockModule->new("Cpanel::PHPFPM")->redefine( rebuild_files => sub { 0 } );
                yield;
            };

            it "should have output to that effect" => sub {
                _run_trap();
                like $trap->{stdout}, qr/Problem encountered while trying to rebuild the PHP-FPM/;
            };

            it "should restart apache" => sub {
                _run_trap();
                is $restart_called, 1;
            };
        };
    };
};

runtests unless caller;

###############
#### helpers ##
###############

sub _run_trap {
    trap { unihook::phpfpm_clean::run("--pkg_list=/tmp/trxn.list") };
}


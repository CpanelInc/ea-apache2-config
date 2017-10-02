#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - t/SOURCES-009-phpconf.pl.t             Copyright(c) 2016 cPanel, Inc.
#                                                           All Rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

package Mock::Cpanel::ProgLang;

use strict;
use warnings;
use parent qw( Cpanel::ProgLang::Supported::php );

our $Packages = [];
our $DefaultPackage;
our $PHPInstalled = 1;

sub new {
    die "PHP Not installed" unless $PHPInstalled;
    return bless( {}, __PACKAGE__ );
}
sub get_installed_packages     { return $Packages }
sub get_system_default_package { return $DefaultPackage }
sub set_system_default_package { shift; my %args = @_; $DefaultPackage = $args{package} }

package Mock::Cpanel::ProgLang::Conf;

use strict;
use warnings;
our $Path;
our $Conf;
sub new { return bless( {}, __PACKAGE__ ) }
sub get_file_path { return $Path }
sub get_conf      { return $Conf }
sub set_conf      { shift; my %args = @_; $Conf = $args{conf} }

package Mock::Cpanel::ConfigFiles::Apache;

use strict;
use warnings;
our $Path;
sub new { return bless( {}, __PACKAGE__ ) }
sub file_conf_php_conf { return $Path }

package Mock::Cpanel::WebServer::Supported::apache;

use strict;
use warnings;
use parent qw( Cpanel::WebServer::Supported::apache );
our %Package;
sub set_package_handler { shift; my %args = @_; $Package{ $args{package} } = $args{type} }

package Mock::Cpanel::WebServer;

use strict;
use warnings;
use parent qw( Cpanel::WebServer );

sub new { return bless( {}, __PACKAGE__ ) }
sub get_server { return Mock::Cpanel::WebServer::Supported::apache->new() }

package t::SOURCES::009_phpconf;

use strict;
use warnings;
use parent qw( Test::Class );
use FindBin ();
use Test::More;
use Test::NoWarnings;
use Test::Trap;
use File::Temp ();
use lib qw( /usr/local/cpanel/t/lib );
use Test::Filesys ();

sub init : Test(startup => 1) {
    require_ok("$FindBin::Bin/../SOURCES/009-phpconf.pl");
    return;
}

sub test_is_handler_supported : Tests(8) {
    note "Testing is_handler_supported()";
    can_ok( 'ea_apache2_config::phpconf', 'is_handler_supported' );

    my @tests = (
        { handler => 'suphp', mods => {}, result => 0, note => "The 'suphp' handler isn't supported when no Apache modules installed" },
        { handler => 'cgi',   mods => {}, result => 0, note => "The 'cgi' handler isn't supported when no Apache modules installed" },
        { handler => 'dso',   mods => {}, result => 0, note => "The 'dso' handler isn't supported when no Apache modules installed" },
        { handler => 'suphp', mods => { suphp => 1 }, result => 1, note => "The 'suphp' handler is supported when the Apache mod_suphp module is installed" },
        { handler => 'dso',   mods => { dso   => 1 }, result => 1, note => "The 'dso' handler is supported when the Apache libphp5 module is installed" },
        { handler => 'cgi',   mods => { cgi   => 1 }, result => 1, note => "The 'cgi' handler is supported when the Apache mod_cgi module is installed" },
        { handler => 'cgi',   mods => { cgi   => 1 }, result => 1, note => "The 'cgi' handler is supported when the Apache mod_cgid module is installed" },
    );

    for my $test (@tests) {
        no warnings qw( redefine );
        local *Cpanel::WebServer::Supported::apache::get_available_handlers = sub { return $test->{mods} };

        use warnings qw( redefine );
        is( ea_apache2_config::phpconf::is_handler_supported( $test->{handler} ), $test->{result}, qq{is_handler_supported: $test->{note}} );
    }

    return;
}

sub test_get_php_config : Tests(5) {
    note "Testing get_php_config()";
    can_ok( 'ea_apache2_config::phpconf', 'get_php_config' );

    no warnings qw( redefine );
    local $INC{'Cpanel/ProgLang.pm'}      = 1;
    local $INC{'Cpanel/ProgLang/Conf.pm'} = 1;
    local *Cpanel::ConfigFiles::Apache::new = sub { return Mock::Cpanel::ConfigFiles::Apache->new() };
    local *Cpanel::ProgLang::new            = sub { return Mock::Cpanel::ProgLang->new() };
    local *Cpanel::ProgLang::Conf::new      = sub { return Mock::Cpanel::ProgLang::Conf->new() };

    no warnings qw( redefine once );
    local *ea_apache2_config::phpconf::get_preferred_handler = sub { return "foobar$$" };

    use warnings qw( redefine once );
    local $Mock::Cpanel::ProgLang::PHPInstalled    = 0;
    local $Mock::Cpanel::ConfigFiles::Apache::Path = "/path/to/apache/cfg$$";
    local $Mock::Cpanel::ProgLang::Conf::Path      = "/path/to/cpanel/cfg$$";

    my $ref = ea_apache2_config::phpconf::get_php_config();
    delete $ref->{args};
    my %expect = ( api => 'new', apache_path => "/path/to/apache/cfg$$", cfg_path => "/path/to/cpanel/cfg$$", packages => [] );
    is_deeply( $ref, \%expect, qq{get_php_config: Contains correct config structure when PHP not installed} ) or diag explain($ref);

    $Mock::Cpanel::ProgLang::PHPInstalled = 1;
    local $Mock::Cpanel::ProgLang::Packages = [qw( x y z )];
    local $Mock::Cpanel::ProgLang::Conf::Conf = { brindle => 1, bovine => 2 };
    $ref = ea_apache2_config::phpconf::get_php_config();
    isa_ok( $ref->{php}, q{Cpanel::ProgLang::Supported::php} );
    delete $ref->{php};
    delete $ref->{args};
    %expect = ( api => 'new', apache_path => "/path/to/apache/cfg$$", cfg_path => "/path/to/cpanel/cfg$$", packages => [qw( x y z )], cfg_ref => {} );
    is_deeply( $ref, \%expect, qq{get_php_config: Returned correct config structure when old packages no longer installed} ) or diag explain $ref;
    is_deeply( $Mock::Cpanel::ProgLang::Conf::Conf, { default => 'z', x => "foobar$$", y => "foobar$$", z => "foobar$$" }, qq{get_php_config: Saved a working php.conf when old packages are no longer installed} ) or diag explain $Mock::Cpanel::ProgLang::Conf::Conf;

    return;
}

sub test_get_rebuild_settings : Tests(10) {
    note "Testing get_rebuild_settings()";
    can_ok( 'ea_apache2_config::phpconf', 'get_rebuild_settings' );

    no warnings qw( redefine );
    local $INC{'Cpanel/ProgLang.pm'}      = 1;
    local $INC{'Cpanel/ProgLang/Conf.pm'} = 1;
    local *Cpanel::ConfigFiles::Apache::new = sub { return Mock::Cpanel::ConfigFiles::Apache->new() };
    local *Cpanel::ProgLang::new            = sub { return Mock::Cpanel::ProgLang->new() };
    local *Cpanel::ProgLang::Conf::new      = sub { return Mock::Cpanel::ProgLang::Conf->new() };

    use warnings qw( redefine );
    local $Mock::Cpanel::ProgLang::PHPInstalled    = 0;
    local $Mock::Cpanel::ConfigFiles::Apache::Path = "/path/to/apache/cfg$$";
    local $Mock::Cpanel::ProgLang::Conf::Path      = "/path/to/cpanel/cfg$$";

    my $ref = ea_apache2_config::phpconf::get_rebuild_settings( ea_apache2_config::phpconf::get_php_config() );
    is_deeply( $ref, {}, q{get_rebuild_settings: No settings retrieved when PHP not installed} );

    $Mock::Cpanel::ProgLang::PHPInstalled = 1;

    my @tests = (
        {
            mods     => { mod_cgi => 1 },
            packages => [qw( x y z )],
            conf => { default => 'x', x => 'cgi', y => 'cgi', z => 'cgi' },
            default  => 'x',                                                                                    # NOTE: In practice, this will be the same as conf variable
            note     => qq{Happy path: all packages and handlers installed and accounted for in config file},
            expected => { default => 'x', x => 'cgi', y => 'cgi', z => 'cgi' },
            output   => qr/\A\z/,
        },
        {
            mods     => { mod_cgi => 1 },
            packages => [qw( x y z )],
            conf     => { default => 'x' },
            default  => 'x',                                                                                            # NOTE: In practice, this will be the same as conf variable
            note     => qq{All packages installed, handlers undefined in config, assign to preferred default -- cgi},
            expected => { default => 'x', x => 'cgi', y => 'cgi', z => 'cgi' },
            output   => qr/\A\z/,
        },
        {
            mods     => { mod_cgi => 1, mod_suphp => 1 },
            packages => [qw( x y z )],
            conf => { default => 'x' },
            default  => 'x',                                                                                              # NOTE: In practice, this will be the same as conf variable
            note     => qq{All packages installed, handlers undefined in config, assign to preferred default -- suphp},
            expected => { default => 'x', x => 'suphp', y => 'suphp', z => 'suphp' },
            output   => qr/\A\z/,
        },
        {
            mods     => { mod_cgi => 1, mod_suphp => 1 },
            packages => [qw( y z )],
            conf => { default => 'x' },
            default  => 'x',                                                                                                                 # NOTE: In practice, this will be the same as conf variable
            note     => qq{The system default package is missing -- default to latest package and use preferred default handler -- suphp},
            expected => { default => 'z', y => 'suphp', z => 'suphp' },
            output   => qr/\A\z/,
        },
    );

    for my $test (@tests) {
        my $handler_changed = 0;

        no warnings qw( redefine once );
        my %supported_handlers = map { $_ => 1 } map { substr( $_, 0, 4 ) eq 'mod_' ? substr( $_, 4 ) : $_ } keys %{ $test->{mods} };
        local *Cpanel::AdvConfig::apache::modules::get_supported_modules = sub { return $test->{mods} };
        local *ea_apache2_config::phpconf::send_notification             = sub { };
        local *ea_apache2_config::phpconf::is_handler_supported          = sub {
            my ($handler) = @_;
            return ( $supported_handlers{$handler} || 0 );
        };

        use warnings qw( redefine once );
        local $Mock::Cpanel::ProgLang::Packages       = $test->{packages};
        local $Mock::Cpanel::ProgLang::Conf::Conf     = $test->{conf};
        local $Mock::Cpanel::ProgLang::DefaultPackage = $test->{default};

        my $settings = trap { ea_apache2_config::phpconf::get_rebuild_settings( ea_apache2_config::phpconf::get_php_config() ) };
        is_deeply( $settings, $test->{expected}, qq{get_rebuild_settings: $test->{note} (settings)} ) or diag explain { expected => $test->{expected}, got => $settings };
        like( $trap->stdout, $test->{output}, qq{get_rebuild_settings: $test->{note} (output)} ) or diag explain { stdout => $trap->stdout(), stderr => $trap->stderr() };
    }

    return;
}

sub test_apply_rebuild_settings : Tests(11) {
    note "Testing apply_rebuild_settings()";
    can_ok( 'ea_apache2_config::phpconf', 'apply_rebuild_settings' );
    %Mock::Cpanel::WebServer::Supported::apache::Package = ();

    my $tmpdir = File::Temp::tempdir( CLEANUP => 1 );
    Test::Filesys::make_structure( $tmpdir, { "apachecfg$$.conf" => q{}, "cpanelcfg$$.conf" => q{} } );

    ok( scalar stat(qq{$tmpdir/apachecfg$$.conf}), q{apply_rebuild_settings: Apache temp config file created} );
    ok( scalar stat(qq{$tmpdir/cpanelcfg$$.conf}), q{apply_rebuild_settings: Cpanel temp config file created} );
    my $ret = ea_apache2_config::phpconf::apply_rebuild_settings( { packages => [], apache_path => qq{$tmpdir/apachecfg$$.conf}, cfg_path => qq{$tmpdir/cpanelcfg$$.conf} }, {} );
    is_deeply( \%Mock::Cpanel::WebServer::Supported::apache::Package, {}, q{apply_rebuild_settings: Didn't apply any packages when PHP isn't installed} );
    ok( $ret,                                       q{apply_rebuild_settings: Correct return value when no PHP packages installed} );
    ok( !scalar stat(qq{$tmpdir/apachecfg$$.conf}), q{apply_rebuild_settings: Apache temp config file removed when no PHP packages installed} );
    ok( !scalar stat(qq{$tmpdir/cpanelcfg$$.conf}), q{apply_rebuild_settings: Cpanel temp config file removed when no PHP packages installed} );

    my $caught_error = 0;

    no warnings qw( redefine );
    local $INC{'Cpanel/WebServer.pm'} = 1;
    local *Cpanel::WebServer::new = sub { return Mock::Cpanel::WebServer->new() };
    local *Cpanel::Logger::die = sub { $caught_error = 1 };

    use warnings qw( redefine );
    my @packages = qw( x y z );
    my %settings = ( x => "xfoobar$$", y => "yfoobaz$$", z => "zfoofoo$$", default => 'x' );
    my $php      = Mock::Cpanel::ProgLang->new();
    $ret = trap { ea_apache2_config::phpconf::apply_rebuild_settings( { api => 'new', php => $php, packages => \@packages }, \%settings ) };
    $trap->return_ok( 0, qq{apply_rebuild_settings: Returned successfully after setting package handlers} );
    is( $Mock::Cpanel::ProgLang::DefaultPackage, q{x}, q{apply_rebuild_settings: Set the correct system default package} );
    delete $settings{default};
    is_deeply( \%Mock::Cpanel::WebServer::Supported::apache::Package, \%settings, q{apply_rebuild_settings: Set each package to the correct handler} );
    ok( !$caught_error, q{apply_rebuild_settings: No errors detected} );
    %Mock::Cpanel::WebServer::Supported::apache::Package = ();

    return;
}

sub test_sanitize_php_config : Tests(5) {
    note "Testing sanitize_php_config()";
    can_ok( 'ea_apache2_config::phpconf', 'sanitize_php_config' );
    is( $ea_apache2_config::phpconf::cpanel_default_php_pkg, "ea-php56", '$cpanel_default_php_pkg is what we expect' );

    no warnings 'redefine';
    local *Cpanel::WebServer::Supported::apache::get_available_handlers = sub { return { suphp => 1 } };

    my $php     = Mock::Cpanel::ProgLang::Conf->new();
    my @non_def = qw(ea-php42 ea-php99 ea-php01);
    ea_apache2_config::phpconf::sanitize_php_config(
        {
            cfg_ref => { default => "ea-php42" },
            packages => [ @non_def, $ea_apache2_config::phpconf::cpanel_default_php_pkg ],
        },
        $php
    );
    is( $Mock::Cpanel::ProgLang::Conf::Conf->{default}, "ea-php42", "sanitize_php_config(): given default is kept" );

    ea_apache2_config::phpconf::sanitize_php_config(
        {
            cfg_ref  => {},
            packages => [ @non_def, $ea_apache2_config::phpconf::cpanel_default_php_pkg ],
        },
        $php
    );
    is( $Mock::Cpanel::ProgLang::Conf::Conf->{default}, $ea_apache2_config::phpconf::cpanel_default_php_pkg, "sanitize_php_config(): uses \$cpanel_default_php_pkg when default is not given and \$cpanel_default_php_pkg is installed" );

    ea_apache2_config::phpconf::sanitize_php_config(
        {
            cfg_ref  => {},
            packages => \@non_def,
        },
        $php
    );
    is( $Mock::Cpanel::ProgLang::Conf::Conf->{default}, "ea-php99", "sanitize_php_config(): uses newest when default is not given and \$cpanel_default_php_pkg is not installed" );

    return;
}

#TODO: Update SOURCES/009-phpconf.pl to actually execute as a script (its all in functions right now)

unless ( caller() ) {
    my $test = __PACKAGE__->new();
    plan tests => $test->expected_tests(+1);
    $test->runtests();
}


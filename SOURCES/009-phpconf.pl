#!/usr/local/cpanel/3rdparty/bin/perl

# Copyright (c) 2015, cPanel, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

use strict;
use Cpanel::Imports;
use Try::Tiny;
use Cpanel::AdvConfig::apache::modules ();
use Cpanel::ConfigFiles::Apache        ();
use Cpanel::DataStore                  ();
use Cpanel::Lang::PHP::Settings        ();
use Cpanel::Notify                     ();
use POSIX qw( :sys_wait_h );

sub is_handler_supported {
    my $handler   = shift;
    my $supported = 0;

    my %handler_map = (
        'suphp' => [q{mod_suphp}],
        'cgi'   => [ q{mod_cgi}, q{mod_cgid} ],
        'dso'   => [q{libphp5}],                  # TODO: This is here until EA-3711 is complete
    );

    my $modules = Cpanel::AdvConfig::apache::modules::get_supported_modules();
    for my $mod ( @{ $handler_map{$handler} } ) {
        $supported = 1 if $modules->{$mod};
    }

    return $supported;
}

sub send_notification {
    my ( $package, $language, $webserver, $missing_handler, $replacement_handler ) = @_;

    my %args = (
        class            => q{EasyApache::EA4_LangHandlerMissing},
        application      => q{universal_hook_phpconf},
        constructor_args => [
            package             => $package,
            language            => $language,
            webserver           => $webserver,
            missing_handler     => $missing_handler,
            replacement_handler => $replacement_handler
        ],
    );

    # No point in catching the failure since we can't do anything
    # about here anyways.
    try {
        my $class = Cpanel::Notify::notification_class(%args);
        waitpid( $class->{'_icontact_pid'}, WNOHANG );
    };

    return 1;
}

my $apacheconf = Cpanel::ConfigFiles::Apache->new();
my ( $php, @phps );

# If there are no PHPs installed, we could get an exception.
try {
    $php = Cpanel::Lang::PHP::Settings->new();
    @phps = @{ $php->php_get_installed_versions() } or die;
}
catch {
    unlink $apacheconf->file_conf_php_conf() . '.yaml';
    unlink $apacheconf->file_conf_php_conf();
    print locale->maketext("No PHP packages are installed.") . "\n";
    exit;
};

my $yaml = Cpanel::DataStore::fetch_ref( $apacheconf->file_conf_php_conf() . '.yaml' );

# We can't assume that suphp will always be available.  We'll try to
# use it if the module is there, but if not, we'll fall back to cgi.
# Based on the way ea-php* packages install, we can guarantee that cgi
# will always be available.
my %php_settings = ( dryrun => 0, restart => 0 );
for my $ver (@phps) {
    my $old_handler = $yaml->{$ver} || 'suphp';    # prefer suphp if no handler defined
    my $new_handler = is_handler_supported($old_handler) ? $old_handler : 'cgi';

    if ( $old_handler ne $new_handler ) {
        print locale->maketext(q{WARNING: You removed a configured [asis,Apache] handler.}), "\n";
        print locale->maketext( q{The “[_1]” package will revert to the “[_2]”[comment,the web server handler that will be used in its place (e.g. cgi)] “[_3]” handler.}, $ver, 'Apache', $new_handler ), "\n";
        send_notification( $ver, 'PHP', 'Apache', $old_handler, $new_handler );
    }

    $php_settings{$ver} = $new_handler;
}

# Let's make sure that the system default version is still actually
# installed.  If not, we'll try to set the highest-numbered version
# that we have.  We are guaranteed to have at least one installed
# version at this point in the script.
#
# It is possible that the system default setting may not match what we
# got from the YAML file, so let's make sure things are as we expect.
# System default will take precedence.
my $sys_default = eval { $php->php_get_system_default_version(); };
($sys_default) = grep { $_ eq $sys_default } @phps if defined $sys_default;

my $yaml_default = $yaml->{'phpversion'} || undef;
($yaml_default) = grep { $_ eq $yaml_default } @phps if defined $yaml_default;

# Both vars will be either an installed version, or undef.  Undef can
# mean that the previously-set version is not installed, or there was
# no setting in the first place, or there was some other error.
$php_settings{version} = $sys_default || $yaml_default || $phps[-1];

try {
    $php->php_set_system_default_version(%php_settings);
}
catch {
    logger->die("$_");    # copy $_ since it can be magical
};


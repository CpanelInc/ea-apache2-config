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
my $handler = ( Cpanel::AdvConfig::apache::modules::is_supported('mod_suphp') ? 'suphp' : 'cgi' );

my %php_settings = ( dryrun => 0 );
for my $ver (@phps) {
    $php_settings{$ver} = $yaml->{$ver} || $handler;
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
}


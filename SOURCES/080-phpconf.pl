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
use Cpanel::DataStore           ();
use Cpanel::ConfigFiles::Apache ();
use Cpanel::Lang::PHP::Settings ();

my $php  = eval { Cpanel::Lang::PHP::Settings->new(); };         # We silently ignore the “No PHP packages are installed.” exception that this throws because an empty list is not an error
my @phps = eval { @{ $php->php_get_installed_versions() }; };    # TODO: fix php_get_installed_versions(). We silently ignore the “No PHP packages are installed.” exception that this throws because an empty list is not an error. Unfortunately, any actual errors this throws won’t be catchable until it throws a specific type we can look for and ignore.

if ( !@phps ) {
    my $apacheconf = Cpanel::ConfigFiles::Apache->new();
    unlink $apacheconf->file_conf_php_conf() . '.yaml';
    unlink $apacheconf->file_conf_php_conf();
    print locale->maketext("No PHP packages are installed.") . "\n";
    exit;
}

my $apacheconf = Cpanel::ConfigFiles::Apache->new();
my $yaml       = Cpanel::DataStore::fetch_ref( $apacheconf->file_conf_php_conf() . '.yaml' );

my %php_settings = ( dryrun => 0 );
for my $ver (@phps) {
    $php_settings{$ver} = $yaml->{$ver} || 'suphp';
}

$php_settings{version} = $yaml->{'phpversion'} || $phps[-1];

try {
    $php->php_set_system_default_version(%php_settings);    # This can return erroneous results for this script’s puproses. See EA-526 for specifics.
}
catch {
    logger->die("$_");                                      # copy $_ since it can be magical
}


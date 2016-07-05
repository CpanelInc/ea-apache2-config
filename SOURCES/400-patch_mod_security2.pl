#!/usr/local/cpanel/3rdparty/bin/perl

# Copyright (c) 2016, cPanel, Inc.
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
use warnings;

use Cpanel::FileUtils;
use Cpanel::Version::Compare;
use File::Copy;
use Whostmgr::Version;
use Whostmgr::ModSecurity;

print "Aligning modsec config to Whostmgr\n";

my $whm_version = Whostmgr::Version::getversion();
print "- Whostmgr version $whm_version\n";
if ( !supports_new_location($whm_version) ) {
    print "- Whostmgr supports conf.d location only\n";
    print "- Migrating modsec2 files to conf.d\n";
    unmigrate_modsec2_config_move();
}
else {
    print "- Whostmgr supports conf.d/modsec location\n";
    print "- No change necessary\n";
}
exit 0;

sub supports_new_location {
    my $version = shift;

    # explicit returns because we will need to add more conditions as we backport
    # the WHM UI interface to each particular version.
    #
    # Future lines should look like:
    # return 1 if ( Cpanel::Version::Compare::compare....( $version, '>=', 'version guaranteed to have backport' ) );
    return 1 if ( Cpanel::Version::Compare::compare_major_release( $version, '>=', '11.58' ) );
    return 0;
}

sub unmigrate_modsec2_config_move {
    my $config_prefix = Whostmgr::ModSecurity::config_prefix();

    print "-  moving $config_prefix/modsec/modsec2.cpanel.conf $config_prefix/modsec2.cpanel.conf\n";
    File::Copy::move( "$config_prefix/modsec/modsec2.cpanel.conf", "$config_prefix/modsec2.cpanel.conf" );

    print "-  moving $config_prefix/modsec/modsec2.cpanel.conf.PREVIOUS $config_prefix/modsec2.cpanel.conf.PREVIOUS\n";
    File::Copy::move( "$config_prefix/modsec/modsec2.cpanel.conf.PREVIOUS", "$config_prefix/modsec2.cpanel.conf.PREVIOUS" );

    print "-  moving $config_prefix/modsec/modsec2.user.conf $config_prefix/modsec2.user.conf\n";
    File::Copy::move( "$config_prefix/modsec/modsec2.user.conf", "$config_prefix/modsec2.user.conf" );

    print "-  moving $config_prefix/modsec/modsec2.user.conf.PREVIOUS $config_prefix/modsec2.user.conf.PREVIOUS\n";
    File::Copy::move( "$config_prefix/modsec/modsec2.user.conf.PREVIOUS", "$config_prefix/modsec2.user.conf.PREVIOUS" );

    print "-  removing modsec2.cpanel.conf include in $config_prefix/modsec2.conf\n";
    Cpanel::FileUtils::regex_rep_file( "$config_prefix/modsec2.conf", { qr{^\s*Include\s+.*/modsec/modsec2\.cpanel\.conf\s*} => "" } );

    print "-  removing modsec2.user.conf include in $config_prefix/modsec2.conf\n";
    Cpanel::FileUtils::regex_rep_file( "$config_prefix/modsec2.conf", { qr{^\s*Include\s+.*/modsec/modsec2\.user\.conf\s*} => "" } );

    return 1;
}


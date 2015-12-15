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
use warnings;
use Cpanel::CachedCommand::Utils ();

#
# First purge all the CachedCommand caches
#
purge_cached_commands();

#
# Rebuild the global cache
#
print "Rebuilding global cache\n";
system('/usr/local/cpanel/bin/build_global_cache');

if ( -x '/usr/local/cpanel/bin/packman' ) {
    print "Rebuilding PackMan caches\n";
    system('/usr/local/cpanel/bin/packman cache');
}

sub purge_cached_commands {

    print "Purging all relavant cached command results\n";

    # Get the directory where the CachedCommand cache files live
    my $cache_dir = Cpanel::CachedCommand::Utils::_get_datastore_dir();

    if ( !defined $cache_dir or !$cache_dir ) {
        print STDERR "Unable to obtain the cached command datastore directory\n";
        return;
    }

    # Guard against getting back something like "/", make sure it is a real cPanel cache dir
    if ( $cache_dir !~ /\.cpanel\/datastore$/ ) {
        print STDERR "Invalid cached command datastore directory:  $cache_dir\n";
        return;
    }

    if ( !-d $cache_dir ) {
        print STDERR "$cache_dir is not a directory\n";
        return;
    }

    my $dh;
    if ( !opendir( $dh, $cache_dir ) ) {
        print STDERR "Unable to open $cache_dir:  $!\n";
        return;
    }

    while ( my $file = readdir($dh) ) {

        my $full_path = "$cache_dir/$file";

        # Only actual files, no subdirs, no . or ..
        next unless -f $full_path;

        # Only actions run on apache
        next unless ( $file =~ /http/ );

        print "Removing:  $full_path\n";
        unlink $full_path or print STDERR "Unable to delete $file:  $!\n";
    }

    closedir($dh);
}


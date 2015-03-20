#!/usr/local/cpanel/3rdparty/bin/perl
# cpanel - purge_cache.pl                         Copyright(c) 2015 cPanel, Inc.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

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


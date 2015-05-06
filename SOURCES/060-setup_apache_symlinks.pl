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

use Cpanel::ConfigFiles::Apache ();

# Get the paths from the paths.conf file
my $apacheconf = Cpanel::ConfigFiles::Apache->new();

# These are the old Easy Apache 3 paths
my $ea3_basedir = '/usr/local/apache';
my $ea3_confdir = "$ea3_basedir/conf";
my $ea3_bindir  = "$ea3_basedir/bin";

my %ea3_paths = (
    dir_logs             => "$ea3_basedir/logs",
    dir_domlogs          => "$ea3_basedir/domlogs",
    dir_modules          => "$ea3_basedir/modules",
    dir_conf_includes    => "$ea3_confdir/includes",
    dir_conf_userdata    => "$ea3_confdir/userdata",
    dir_docroot          => "$ea3_basedir/htdocs",
    file_access_log      => "$ea3_basedir/access_log",
    file_error_log       => "$ea3_basedir/error_log",
    file_conf            => "$ea3_confdir/httpd.conf",
    file_conf_mime_types => "$ea3_confdir/mime.types",
    file_conf_srm_conf   => "$ea3_confdir/srm.conf",
    file_conf_php_conf   => "$ea3_confdir/php.conf",
    bin_httpd            => "$ea3_bindir/httpd",
    bin_apachectl        => "$ea3_bindir/apachectl",
    bin_suexec           => "$ea3_bindir/suexec",
);

for my $dir ( $ea3_basedir, $ea3_bindir, $ea3_confdir ) {
    next if -d $dir;
    if ( !mkdir($dir) ) {
        die "Unable to create $dir: $!\n";
    }
}

eval {
    # Make a symlink from all the old ea3 paths to the new folders
    foreach my $key ( keys %ea3_paths ) {

        # If the old and the new are the same, no symlink required
        if ( $apacheconf->{$key} eq $ea3_paths{$key} ) {
            print "Source and destination same, $ea3_paths{$key}, no need to link\n";
            next;
        }

        # No sense in trying to link to something that doesn't exist
        if ( !-e $apacheconf->{$key} ) {
            print "Target $apacheconf->{$key} doesn't exist, can't link to it\n";
            next;
        }

        # If a symlink already exists, it may be old/wrong, remake it
        if ( -l $ea3_paths{$key} ) {
            if ( readlink( $ea3_paths{$key} ) ne $apacheconf->{$key} ) {
                print "Previous symlink at $ea3_paths{$key}, unlinking\n";
                unlink( $ea3_paths{$key} )
                  or die("Unable to unlink $ea3_paths{$key}:  $!");
            }
            else {
                print "Link already exists:  $ea3_paths{$key} -> $apacheconf->{$key}\n";
                next;
            }
        }

        # If we can see the item to be linked, it is likely visible
        # due to its parent being linked.
        # In any case, don't link on top of an existing file
        if ( -e $ea3_paths{$key} ) {
            print "$ea3_paths{$key} already visible, no need to link\n";
            next;
        }

        print "Linking $ea3_paths{$key} -> $apacheconf->{$key}\n";

        symlink( $apacheconf->{$key}, $ea3_paths{$key} )
          or die("Unable to symlink $ea3_paths{$key} to $apacheconf->{$key}:  $!");
    }
};
if ($@) {
    print "$@\n";

    exit 1;
}


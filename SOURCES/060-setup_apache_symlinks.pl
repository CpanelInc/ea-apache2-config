#!/usr/local/cpanel/3rdparty/bin/perl
# cpanel - 060-setup_apache_symlinks.pl           Copyright(c) 2015 cPanel, Inc.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use strict;
use warnings;

use File::Path                  ();
use Cpanel::ConfigFiles::Apache ();

# Get the paths from the paths.conf file
my $apacheconf = Cpanel::ConfigFiles::Apache->new();

# These are the old Easy Apache 3 paths
my $ea3_basedir = '/usr/local/apache';
my $ea3_confdir = "$ea3_basedir/conf";
my $ea3_bindir  = "$ea3_basedir/bin";

my %ea3_paths = (
    dir_logs    => "$ea3_basedir/logs",
    dir_domlogs => "$ea3_basedir/domlogs",
    dir_modules => "$ea3_basedir/modules",
    dir_conf    => "$ea3_confdir",

    # dir_conf_includes    => "$ea3_confdir/includes",
    # dir_conf_userdata    => "$ea3_confdir/userdata",
    dir_docroot => "$ea3_basedir/htdocs",

    # file_access_log      => "$ea3_basedir/access_log",
    # file_error_log       => "$ea3_basedir/error_log",
    # file_conf            => "$ea3_confdir/httpd.conf",
    # file_conf_mime_types => "$ea3_confdir/mime.types",
    # file_conf_srm_conf   => "$ea3_confdir/srm.conf",
    # file_conf_php_conf   => "$ea3_confdir/php.conf",
    bin_httpd     => "$ea3_bindir/httpd",
    bin_apachectl => "$ea3_bindir/apachectl",
    bin_suexec    => "$ea3_bindir/suexec",
);

# If the directory already exists, assume symlinks setup?
# TODO:  Maybe rename & create anew?
# But, that would have us rebuilding each time a package was re-installed
if ( -d $ea3_basedir ) {
    print "$ea3_basedir directory already exists\n";
    exit;
}

if ( !mkdir($ea3_basedir) ) {
    print STDERR "Unable to create $ea3_basedir:  $1\n";
    exit 1;
}

if ( !mkdir($ea3_bindir) ) {
    print STDERR "Unable to create $ea3_bindir:  $1\n";
    exit 1;
}

eval {
    # Make a symlink from all the old ea3 paths to the new folders
    foreach my $key ( keys %ea3_paths ) {

        # If the old and the new are the same, no symlink required
        next if ( $apacheconf->{$key} eq $ea3_paths{$key} );

        print "Linking $ea3_paths{$key} -> $apacheconf->{$key}\n";

        symlink( $apacheconf->{$key}, $ea3_paths{$key} )
          or die("Unable to symlink $ea3_paths{$key} to $apacheconf->{$key}:  $!");
    }
};
if ($@) {
    print "$@\n";

    # We don't want to leave it half configured, resolve the issue & re-run
    File::Path::remove_tree($ea3_basedir);
    exit 1;
}


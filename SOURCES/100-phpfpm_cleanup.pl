#!/usr/local/cpanel/3rdparty/bin/perl
##############################################################################################
#
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
#
##############################################################################################

use strict;

#use warnings;

use Cpanel::PHP::Config;
use Cpanel::PHPFPM;
use Cpanel::HttpUtils::ApRestart::BgSafe;

##############################################################################################

my $debuglvl       = 1;
my $phpfpm_version = '';
my @pkgs;
my $script_name = $0;
$script_name =~ s/.+\/(.+?)\.pl$/$1/;

foreach my $arg (@ARGV) {
    if ( $arg =~ m/^--pkg_list=(.+)$/ ) {
        my $pkgs_path = $1;
        if ( open( my $pkgs_list_fh, '<', $pkgs_path ) ) {
            foreach my $line (<$pkgs_list_fh>) {
                chomp($line);
                push( @pkgs, $line );
            }
        }
        else {
            die "Found path to packages “$pkgs_path” but could not read from it : $!\n";
        }
    }
}

my $restart_needed = 0;

foreach my $pkg (@pkgs) {
    msglog( 2, "Processing package '$pkg'" );
    if ( $pkg =~ m/^ea-php(\d{2})-php-fpm$/ ) {
        $phpfpm_version = $1;
    }
    else {
        # This is not the package we are looking for /waveshand
        next;
    }

    # Try to determine if we are removing the package or installing it.
    # At this point, if we are installing, it should now exist. If we are removing, it should not.
    my $installing = 0;

    # TODO - move this check to a module, something like Cpanel::PackMan::is_package_installed_quick() ?
    my $rc = system( "rpm", "--quiet", "-q", $pkg );
    if ($rc) {
        $installing = 0;
    }
    else {
        $installing = 1;
    }

    # If we are installing, there presumably isn't anything to clean up. Otherwise, proceed with the purge. -.-
    if ($installing) {
        msglog( 0, "[$pkg] No need to clean user files since we are installing." );
        next;
    }
    else {
        msglog( 0, "Cleaning up PHP-FPM configs for version $phpfpm_version since we are removing the package." );
    }

    # If we get here, we're going to want to restart Apache
    $restart_needed = 1;

    # Build a list of users on a certain version of PHP-FPM
    my $users_ref = get_users_on_fpm_version($phpfpm_version);

    # Disable any user currently configured for this version of PHP-FPM
    disable_all_fpm_users_for_version( $phpfpm_version, $users_ref );

    # Rebuild the Apache config
    my $php_cfg_ref = Cpanel::PHP::Config::get_php_config_for_users($users_ref);
    if ( Cpanel::PHPFPM::rebuild_files( $php_cfg_ref, 0, 1, 1 ) ) {
        msglog( 0, "All domains that were on ea-php${phpfpm_version}-php-fpm should be back to system defaults." );
    }
    else {
        msglog( 0, "Problem encountered while trying to rebuild the PHP-FPM related configuration files. Please check the Apache server to be sure it is running correctly." );
    }
}

if ($restart_needed) {

    # Finally, restart apache with the updated config
    msglog( 0, "Restarting Apache" );
    Cpanel::HttpUtils::ApRestart::BgSafe::restart;
}

exit;

##############################################################################################
# Functions
##############################################################################################

sub get_users_on_fpm_version {
    my ($version) = @_;
    my @users;

    my $conf_dir_path = ${Cpanel::PHPFPM::Constants::opt_cpanel} . '/ea-php' . $version . '/root/etc/php-fpm.d/';
    if ( opendir( my $user_confs_dir, $conf_dir_path ) ) {
        foreach my $file ( readdir($user_confs_dir) ) {
            if ( $file =~ m/.+\.conf$/ ) {
                if ( open( my $cnf_fh, '<', "$conf_dir_path/$file" ) ) {
                    while ( my $line = <$cnf_fh> ) {
                        $line =~ s/\s+//g;
                        chomp($line);
                        if ( $line =~ m/^user=(.*)$/ ) {
                            my $username = $1;
                            push( @users, $username );
                        }
                    }
                }
            }
        }
        close($user_confs_dir);
    }
    return \@users;
}

sub disable_all_fpm_users_for_version {
    my ( $version, $users_ref ) = @_;

    # We might get $version as just the numbers like 55, 56, 70, etc, or a full string, like ea-php55, ea-php56 or ea-php70
    if ( $version =~ m/ea-php(\d+)/ ) {
        $version = $1;
    }

    # We'll iterate through all the .conf files in this version's php-fom.d config directory and build a list of users on this version.
    # Then we'll go through those users and remove their yaml configs ?

    foreach my $user ( @{$users_ref} ) {
        if ( opendir( my $userdata_dir, '/var/cpanel/userdata/' . $user ) ) {
            foreach my $file ( readdir($userdata_dir) ) {
                if ( $file =~ m/.+\.php\-fpm\.yaml$/ ) {
                    unlink( $userdata_dir, '/var/cpanel/userdata/' . $user . '/' . $file );
                }
            }
            close($userdata_dir);
        }
    }
    return;
}

sub msglog {
    my ( $lvl, $text ) = @_;
    if ( $lvl <= $debuglvl ) {
        my $ts     = scalar( localtime(time) );
        my @caller = caller();
        print STDOUT "[$ts] [$script_name] $text\n";
    }
    return;
}

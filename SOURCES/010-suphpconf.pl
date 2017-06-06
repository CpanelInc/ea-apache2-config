#!/usr/local/cpanel/3rdparty/bin/perl
# cpanel - 010-suphpconf.pl                          Copyright 2017 cPanel, Inc.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited
package suphpconf;

use strict;
use warnings;

use Cpanel::SysPkgs::SCL ();

our $suphpconf = '/etc/suphp.conf';

run() unless caller;

sub run {
    if ( -e $suphpconf ) {
        if ( !-e "/usr/local/bin/ea_convert_php_ini" ) {    # This madness will go away with EA-5696
            warn "Unable to update /etc/suphp.conf without the ea-cpanel-tools RPM installed.\n";
        }
        else {
            require "/usr/local/bin/ea_convert_php_ini";    ##no critic (RequireBarewordIncludes) This madness will go away with EA-5696
            my $parser   = Parse::PHP::Ini->new;
            my $tree     = $parser->parse( path => $suphpconf );
            my $handlers = $parser->get_matching_section( $tree, 'handlers' );
            if ( !$handlers ) {
                $handlers = $parser->make_section_node( 'handlers', -1 );
                $tree->add_daughter($handlers);
            }

            my %packages;
            @packages{ @{ Cpanel::SysPkgs::SCL::get_scl_versions(qr/\w+-php/) } } = ();

            # update/cleanout existing entries
            for my $daughter ( @{ $handlers->{daughters} } ) {
                if ( $daughter->{name} =~ m{application/x-httpd-(.*)} ) {
                    my $pkg = $1;
                    if ( exists $packages{$pkg} ) {
                        my $cgi_path = _get_cgi_path($pkg);
                        my $count    = $daughter->{attributes}{line};                                                           # TODO: make this something else?
                        my $tmp      = $parser->make_setting_node( "application/x-httpd-$pkg", qq{"php:$cgi_path"}, $count );
                        my $attr     = $tmp->attribute();
                        $parser->update_node( $daughter, $attr );
                        print "Ensuring current entry for “$pkg” is correct …\n";
                        $packages{$pkg} = "update";
                    }
                    else {
                        print "Ignoring current entry for “$pkg” …\n";
                        $packages{$pkg} = "ignore";
                    }
                }
            }

            # add entries reflecting the actual state
            for my $pkg ( keys %packages ) {
                if ( !$packages{$pkg} ) {
                    my $cgi_path = _get_cgi_path($pkg);
                    my $count    = 0;                                                                                       # TODO: make this something else?
                    my $setting  = $parser->make_setting_node( "application/x-httpd-$pkg", qq{"php:$cgi_path"}, $count );
                    $handlers->add_daughter($setting);
                    print "Adding entry for “$pkg” …\n";
                    $packages{$pkg} = "add";
                }
            }

            # write $suphpconf
            _write_suphpconf($tree);
        }
    }
    else {
        print "Nothing to do ($suphpconf does not exist)\n";
    }
    return;
}

###############
#### helpers ##
###############

sub _get_cgi_path {
    my ($pkg) = @_;

    my $cgi_path = Cpanel::SysPkgs::SCL::get_scl_prefix($pkg) . "/root/usr/bin/php-cgi";
    if ( !-x $cgi_path ) {
        warn "$cgi_path is not executable, please rectify (e.g. a symlink …/root to the right spot should do the trick)\n";
    }

    return $cgi_path;
}

sub _write_suphpconf {
    my ($tree) = @_;

    # Encapsualte the madness here, NS use noted in /usr/local/bin/ea_convert_php_ini
    no warnings "once";
    local $ea_convert_php_ini_file::Cfg{force} = 1;
    ea_convert_php_ini_file::write_php_ini( $tree, $suphpconf );
}

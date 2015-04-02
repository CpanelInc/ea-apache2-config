#!/usr/local/cpanel/3rdparty/bin/perl
# cpanel 070-cloudlinux-cagefs                    Copyright(c) 2015 cPanel, Inc.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use strict;
use Cpanel::Imports;
use Cpanel::CloudLinux ();

if ( Cpanel::CloudLinux::installed() && _has_lines_matching( '/etc/cagefs/cagefs.mp', qr{^\s*[!@#]?/\w+} ) ) {
    print locale->maketext('Updating the [asis,CloudLinux CageFS] virtual filesystem …') . "\n";

    system('/usr/sbin/cagefsctl --update --force-update')
      && logger->warn("/usr/sbin/cagefsctl exited non-zero: $?");

    print "\n";
    print locale->maketext(' … done.') . "\n";
}

sub _has_lines_matching {
    my ( $file, $regexp ) = @_;
    return if !-s $file || !-f _;

    my $matches = 0;
    if ( open( my $fh, '<', $file ) ) {
        while ( my $line = <$fh> ) {
            if ( $line =~ $regexp ) {
                $matches = 1;
                last;
            }
        }
        close($fh);
        return 1 if $matches;
    }
    else {
        logger->warn("Could not read $file: $!");
    }

    return;
}

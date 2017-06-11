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
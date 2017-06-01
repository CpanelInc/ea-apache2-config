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
use Cpanel::PackMan    ();
use Cpanel::FileUtils  ();

if ( Cpanel::CloudLinux::installed() ) {
    my $changed_line     = 0;
    my $map_path         = '/etc/cagefs/cagefs.mp';
    my $user_secdata_str = '%/var/cpanel/secdatadir/users';
    my $match_line_qr    = qr/^\s*\Q$user_secdata_str\E\s*$/;    #\s*$ will get the newline if it is there or not (e.g. it is at the end of the file w/ no newline)

    if ( Cpanel::PackMan->new->is_installed("ea-apache24-mod_security2") ) {
        if ( !_has_lines_matching( $map_path, $match_line_qr ) ) {
            print locale->maketext( 'Adding “[_1]” to “[_2]” …', $user_secdata_str, $map_path ) . "\n";

            if ( open my $fh, '>>', $map_path ) {
                print {$fh} "\n$user_secdata_str\n";
                close $fh;
                $changed_line++;
            }
            else {
                warn locale->maketext(" … failed: $!"), "\n";
            }
        }
    }
    else {

        if ( _has_lines_matching( $map_path, $match_line_qr ) ) {
            print locale->maketext( 'Removing “[_1]” from “[_2]” …', $user_secdata_str, $map_path ) . "\n";

            if ( Cpanel::FileUtils::regex_rep_file( $map_path, { $match_line_qr => "" } ) ) {
                $changed_line++;
            }
            else {
                logger->warn( locale->maketext(" … failed: $!") . "\n" );
            }
        }
    }

    if ( $changed_line || _has_lines_matching( $map_path, qr{^\s*[!@#%]?/\w+} ) ) {
        print locale->maketext('Updating the [asis,CloudLinux CageFS] virtual filesystem …') . "\n";

        system('/usr/sbin/cagefsctl --update --force-update')
          && logger->warn("/usr/sbin/cagefsctl exited non-zero: $?");

        print "\n";
        print locale->maketext(' … done.') . "\n";
    }
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

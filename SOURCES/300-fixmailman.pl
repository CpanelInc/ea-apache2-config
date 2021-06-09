#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - SOURCES/300-fixmailman.pl              Copyright(c) 2016 cPanel, Inc.
#                                                           All Rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

package ea_apache24_config_runtime::SOURCES::300_fixmailman;

use strict;
use warnings;
use Cpanel::Mailman::Perms   ();
use Cpanel::SafeRun::Simple  ();
use Cpanel::Daemonizer::Tiny ();

our @Steps = (
    {
        name => 'Fix mailman package directories',
        code => \&fix_pkg_dirs,
    },
    {
        name => 'Fix mailing list perms',
        code => \&fix_list_dirs,
    },
);

# Fixes the mailing list archive directories based on Apache environment
sub fix_list_dirs {
    my $script = '/usr/local/cpanel/scripts/fixmailman';
    Cpanel::SafeRun::Simple::saferun($script) if -x $script;
    return 1;    # it doesn't return a proper exit code on success, so we ignore it
}

# Fixes the permissions of the core mailman directories...
# because this used to installed without a package on systems < 11.57
sub fix_pkg_dirs {
    my $perm = Cpanel::Mailman::Perms->new();
    $perm->set_perms();    # this always assumes success, so no point in checking retval
    return 1;
}

sub main {
    my $argv = shift;

    for my $step (@Steps) {
        print "$step->{name} …\n";
        my $pid = Cpanel::Daemonizer::Tiny::run_as_daemon(
            sub {
                $0 = $step->{name};
                $step->{code}->($argv);
                return;    # nobody is listening
            }
        );
        print " … PID $pid\n";
    }

    return 0;
}

exit( __PACKAGE__->main( \@ARGV ) ) unless caller();

1;

__END__

#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - t/SOURCES-000-local_template_check.t      Copyright 2017 cPanel, Inc.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use strict;
use warnings;

use Test::More tests => 8 + 1;
use Test::NoWarnings;
use Test::Trap;

use File::Temp ();
use File::Slurp 'write_file';

use FindBin;
require_ok "$FindBin::Bin/../SOURCES/000-local_template_check";

my $dir       = File::Temp->newdir();
my $json_file = "$dir/000-local_template_check.json";

no warnings "redefine", "once";    ## no critic qw(TestingAndDebugging::ProhibitNoWarnings)
local $ea_apache24_config_runtime::SOURCES::000_local_template_check::tt_dir = $dir;
my $_send_new     = 0;
my $_send_updated = 0;
my $_send_unknown = 0;
local *ea_apache24_config_runtime::SOURCES::000_local_template_check::_send = sub { $_[0] =~ m/Updated$/ ? $_send_updated++ : $_[0] =~ m/New$/ ? $_send_new++ : $_send_unknown++ };
use warnings "redefine", "once";

my %tts = _setup($dir);

# no .local, no data
trap { ea_apache24_config_runtime::SOURCES::000_local_template_check::run(); };
is_deeply( [ $_send_new, $_send_updated, $_send_unknown ], [ 0, 0, 0 ], "no .local, no data: no notificaiton sent" );
ok( -e $json_file, "no .local, no data: data created" );

# no .local, w/ data
trap { ea_apache24_config_runtime::SOURCES::000_local_template_check::run(); };
is_deeply( [ $_send_new, $_send_updated, $_send_unknown ], [ 0, 0, 0 ], "no .local, w/ data: no notificaiton sent" );

# .local, no data
write_file( "$dir/$tts{'ea4_main.default'}", "# oh hai LOCAL GUY" );
unlink($json_file);
trap { ea_apache24_config_runtime::SOURCES::000_local_template_check::run(); };
is_deeply( [ $_send_new, $_send_updated, $_send_unknown ], [ 1, 0, 0 ], ".local, no data: new notificaiton sent" );
ok( -e $json_file, ".local, no data: data created" );

# .local, w/ data (matches)
trap { ea_apache24_config_runtime::SOURCES::000_local_template_check::run(); };
is_deeply( [ $_send_new, $_send_updated, $_send_unknown ], [ 1, 0, 0 ], ".local, w/ data (matches): no notification sent" );

# .local, w/ data (mismatches)
write_file( "$dir/ea4_main.default", "# oh hai updated ea4_main.default" );
trap { ea_apache24_config_runtime::SOURCES::000_local_template_check::run(); };
is_deeply( [ $_send_new, $_send_updated, $_send_unknown ], [ 1, 1, 0 ], ".local, w/ data (mismatches): updated notification sent" );

###############
#### helpers ##
###############

sub _setup {
    my ($dir) = @_;

    for my $tt ( keys %ea_apache24_config_runtime::SOURCES::000_local_template_check::templates ) {
        write_file( "$dir/$tt", "# oh hai $tt" );
    }

    return %ea_apache24_config_runtime::SOURCES::000_local_template_check::templates;
}

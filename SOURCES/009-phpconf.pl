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

package ea_apache2_config::phpconf;

use strict;
use Cpanel::Imports;
use Cpanel::PackMan ();
use Try::Tiny;
use Cpanel::ConfigFiles::Apache     ();
use Cpanel::Config::LoadUserDomains ();
use Cpanel::Config::LoadCpUserFile  ();
use Cpanel::Exception               ();
use Cpanel::WebServer::Userdata     ();
use Cpanel::DataStore               ();
use Cpanel::EA4::Util               ();
use Cpanel::Notify                  ();
use Cpanel::ProgLang                ();
use Cpanel::WebServer               ();
use Getopt::Long                    ();
use POSIX qw( :sys_wait_h );

our @PreferredHandlers      = qw( suphp dso cgi );
our $cpanel_default_php_pkg = "ea-php" . Cpanel::EA4::Util::get_default_php_version();
$cpanel_default_php_pkg =~ s/\.//g;

my ( $php, $server );

sub debug {
    my $cfg = shift;
    my $t   = localtime;
    print "[$t] DEBUG: @_\n" if $cfg->{args}->{debug};
}

sub is_handler_supported {
    my ( $handler, $package ) = @_;

    $php    ||= Cpanel::ProgLang->new( type => 'php' );
    $server ||= Cpanel::WebServer->new()->get_server( type => 'apache' );

    my $ref = $server->get_available_handlers( lang => $php, package => $package );
    return 1 if $ref->{$handler};
    return 0;
}

sub send_notification {
    my ( $package, $language, $webserver, $missing_handler, $replacement_handler ) = @_;

    my %args = (
        class            => q{EasyApache::EA4_LangHandlerMissing},
        application      => q{universal_hook_phpconf},
        constructor_args => [
            package             => $package,
            language            => $language,
            webserver           => $webserver,
            missing_handler     => $missing_handler || 'UNDEFINED',
            replacement_handler => $replacement_handler
        ],
    );

    # No point in catching the failure since we can't do anything
    # about here anyways.
    try {
        my $class = Cpanel::Notify::notification_class(%args);
        waitpid( $class->{'_icontact_pid'}, WNOHANG );
    };

    return 1;
}

sub get_preferred_handler {
    my $package = shift;
    my $cfg     = shift;

    my $old_handler = $cfg->{$package} || $PreferredHandlers[0];
    my $new_handler;

    if ( is_handler_supported( $old_handler, $package ) ) {
        $new_handler = $old_handler;
    }
    else {
        for my $handler (@PreferredHandlers) {
            last                    if $new_handler;
            $new_handler = $handler if is_handler_supported( $handler, $package );
        }
    }

    if ( !$new_handler ) {
        my $def = Cpanel::EA4::Util::get_default_php_handler();
        logger->info("Could not find a handler for $package. Defaulting to “$def” so that, at worst case, we get an error instead of source code.");
        $new_handler = $def;
    }

    return $new_handler;
}

# EA-3819: The cpanel api calls depend on php.conf having all known packages
# to be in php.conf.  This will update php.conf with some temporary
# values just in case they're missing.  This will also remove entries
# if they no longer installed.
sub sanitize_php_config {
    my $cfg  = shift;
    my $prog = shift;

    return 1 unless scalar @{ $cfg->{packages} };

    # The %save hash is used to ensure cpanel has a basic php.conf that will
    #   not break the MultiPHP EA4 code if a package or handler is removed
    #   from the system while it's configured.  It will iterate over all
    #   possible handler attempting to find a suitable (and supported)
    #   handler.  It will resort to the Cpanel::EA4::Util::get_default_php_handler() handler if nothing else
    #   is supported.
    #
    # Finally, the cfg_ref hash is what this applications uses to update
    #   packages/handlers to a "preferred" one if the current is missing or
    #   no longer installed.
    my %save    = %{ $cfg->{cfg_ref} };
    my $default = delete $cfg->{cfg_ref}{default};

    # remove packages which are no longer installed
    for my $pkg ( keys %{ $cfg->{cfg_ref} } ) {
        unless ( grep( /\A\Q$pkg\E\z/, @{ $cfg->{packages} } ) ) {
            delete $cfg->{cfg_ref}->{$pkg};
            delete $save{$pkg};
        }
    }

    # add packages which are newly installed and at least make sure it's a valid handler
    for my $pkg ( @{ $cfg->{packages} } ) {
        $save{$pkg} = get_preferred_handler( $pkg, \%save );
    }

    # make sure the default package has been assigned
    if ( !defined $default ) {
        my @packages = sort @{ $cfg->{packages} };

        # if we have $cpanel_default_php_pkg use that, otherwise use the latest that is installed
        $default = grep( { $_ eq $cpanel_default_php_pkg } @packages ) ? $cpanel_default_php_pkg : $packages[-1];
    }

    $save{default} = $default;

    # and only allow a single dso handler, set the rest to Cpanel::EA4::Util::get_default_php_handler()

    !$cfg->{args}{dryrun} && $prog->set_conf( conf => \%save );

    return 1;
}

# Retrieves current PHP
sub get_php_config {
    my $argv = shift || [];

    my %cfg = ( packages => [], args => { dryrun => 0, debug => 0 } );

    Getopt::Long::Configure(qw( pass_through ));    # not sure if we're passed any args by the universal hooks plugin
    Getopt::Long::GetOptionsFromArray(
        $argv,
        dryrun => \$cfg{args}{dryrun},
        debug  => \$cfg{args}{debug},
    );

    my $apacheconf = Cpanel::ConfigFiles::Apache->new();

    eval {
        require Cpanel::ProgLang;
        require Cpanel::ProgLang::Conf;
    };

    # Need to use the old API, not new one
    if ($@) {
        $cfg{api}         = 'old';
        $cfg{apache_path} = $apacheconf->file_conf_php_conf();
        $cfg{cfg_path}    = $cfg{apache_path} . '.yaml';

        try {
            require Cpanel::Lang::PHP::Settings;

            my $php = Cpanel::Lang::PHP::Settings->new();
            $cfg{php}      = $php;
            $cfg{packages} = $php->php_get_installed_versions();
            $cfg{cfg_ref}  = Cpanel::DataStore::fetch_ref( $cfg{cfg_path} );
        };
    }
    else {
        # get basic information in %cfg in case php isn't installed
        my $prog = Cpanel::ProgLang::Conf->new( type => 'php' );
        $cfg{api}         = 'new';
        $cfg{apache_path} = $apacheconf->file_conf_php_conf();    # hack until we can add this API to Cpanel::WebServer
        $cfg{cfg_path}    = $prog->get_file_path();

        try {
            my $php = Cpanel::ProgLang->new( type => 'php' );     # this will die if PHP isn't installed
            $cfg{php}      = $php;
            $cfg{packages} = $php->get_installed_packages();
            $cfg{cfg_ref}  = $prog->get_conf();
        };

        sanitize_php_config( \%cfg, $prog );
    }

    return \%cfg;
}

sub get_rebuild_settings {
    my $cfg = shift;
    my $ref = $cfg->{cfg_ref};
    my %settings;

    return {} unless @{ $cfg->{packages} };

    my $php = $cfg->{php};

    # We can't assume that suphp will always be available for each package.
    # This will iterate over each package and verify that the handler is
    # installed.  If it's not, then revert to the Cpanel::EA4::Util::get_default_php_handler() handler,
    # which should be installed (if it is 'cgi' then it is available by default).

    for my $package ( @{ $cfg->{packages} } ) {
        my $old_handler = $ref->{$package} || '';
        my $new_handler = get_preferred_handler( $package, $ref );

        if ( $old_handler ne '' && $old_handler ne $new_handler ) {
            print locale->maketext(q{WARNING: You removed a configured [asis,Apache] handler.}), "\n";
            print locale->maketext( q{The “[_1]” package will revert to the “[_2]”[comment,the web server handler that will be used in its place (e.g. cgi)] “[_3]” handler.}, $package, 'Apache', $new_handler ), "\n";
            $cfg->{args}->{dryrun} && send_notification( $package, 'PHP', 'Apache', $old_handler, $new_handler );
        }

        $settings{$package} = $new_handler;
    }

    if ( $cfg->{api} eq 'old' ) {
        my $cur_sys_default = eval { $php->php_get_system_default_version() };
        $settings{phpversion} = _ensure_default_key_is_valid( $cur_sys_default => $cfg );
    }
    else {
        my $cur_sys_default = $php->get_system_default_package();
        $settings{default} = _ensure_default_key_is_valid( $cur_sys_default => $cfg );
    }

    return \%settings;
}

sub _ensure_default_key_is_valid {
    my ( $cur_sys_default, $cfg ) = @_;

    $cur_sys_default = undef if !$cur_sys_default || !grep { $cur_sys_default eq $_ } @{ $cfg->{packages} };
    my $def = $cur_sys_default || Cpanel::EA4::Util::get_default_php_version();
    if ( $def =~ m/\./ ) {
        $def = "ea-php$def";
        $def =~ s/\.//g;
    }

    my $def_hr = Cpanel::PackMan->instance->pkg_hr($def) || {};
    $def = $cfg->{packages}[-1] if !$def_hr->{version_installed};

    return $def;
}

sub apply_rebuild_settings {
    my $cfg      = shift;
    my $settings = shift;

    if ( $#{ $cfg->{packages} } == -1 ) {
        debug( $cfg, "No PHP packages installed.  Removing configuration files." );
        logger->info("!!!! No PHPs installed! !!\nUsers’ PHP settings will be left as is. That way PHP requests will get an error instead of serving source code and potentially sensitive data like database credentials.");
        !$cfg->{args}->{dryrun} && unlink( $cfg->{apache_path}, $cfg->{cfg_path} );
        return 1;
    }

    try {
        if ( $cfg->{api} eq 'old' ) {
            my %rebuild = %$settings;
            $rebuild{restart} = 0;
            $rebuild{dryrun}  = 0;
            $rebuild{version} = $settings->{phpversion};
            debug( $cfg, "Updating PHP using old API" );
            !$cfg->{args}->{dryrun} && $cfg->{php}->php_set_system_default_version(%rebuild);
        }
        else {
            my %pkginfo = %$settings;
            my $default = delete $pkginfo{default};

            debug( $cfg, "Setting the system default PHP package to the '$default' handler" );
            !$cfg->{args}->{dryrun} && $cfg->{php}->set_system_default_package( package => $default );
            debug( $cfg, "Successfully updated the system default PHP package" );

            require Cpanel::WebServer;
            my $apache = Cpanel::WebServer->new->get_server( type => "apache" );

            my $disable_flag_file = "/var/cpanel/ea4-disable_009-phpconf.pl_user_setting_validation_and_risk_breaking_PHP_based_sites_and_exposing_sensitive_data_in_PHP_source_code";

            while ( my ( $pkg, $handler ) = each(%pkginfo) ) {
                debug( $cfg, "Setting the '$pkg' package to the '$handler' handler" );
                if ( !$cfg->{args}->{dryrun} ) {
                    $apache->set_package_handler(
                        type    => $handler,
                        lang    => $cfg->{php},
                        package => $pkg,
                    );
                    try {
                        if ( -e $disable_flag_file ) {
                            die "Ensuring that user settings are still valid is disabled via the existence of $disable_flag_file:\n\t!!!! your PHP based sites may be broken and exposing sensitive data in the source code !!\n";
                        }

                        $apache->update_user_package_handlers(
                            type    => $handler,
                            lang    => $cfg->{php},
                            package => $pkg
                        );
                    }
                    catch {
                        logger->info("Error updating user package handlers for $pkg: $_");
                    };
                }
                debug( $cfg, "Successfully updated the '$pkg' package" );
            }

            # now that existing packages are ship shape, let’s handle users still set to non-existent version
            if ( -e $disable_flag_file ) {
                logger->info("Ensuring that user settings are still valid is disabled via the existence of $disable_flag_file:\n\t!!!! your PHP based sites may be broken and exposing sensitive data in the source code !!");
            }
            else {
                update_users_set_to_non_existant_phps( $apache, $cfg->{php}, "inherit" );
            }
        }
    }
    catch {
        logger->die("$_");    # copy $_ since it can be magical
    };

    return 1;
}

sub update_users_set_to_non_existant_phps {
    my ( $apache, $lang, $default ) = @_;

    my ( %users, @error );
    Cpanel::Config::LoadUserDomains::loadtrueuserdomains( \%users, 1 );

    my %installed;
    @installed{ @{ $lang->get_installed_packages() } } = ();

    # this should not be possible *but* just in case
    if ( !keys %installed ) {
        logger->info("!!!! No PHPs installed! !!\nUsers’ PHP settings will be left as is. That way PHP requests will get an error instead of serving source code and potentially sensitive data like database credentials.");
        return;
    }

    for my $user ( keys %users ) {
        next unless $users{$user};    # some accounts are invalid and don't contain a domain in the /etc/trueusersdomain configuration file

        my $cfg = try { Cpanel::Config::LoadCpUserFile::load_or_die($user) };
        next unless $cfg;
        next if $cfg->{PLAN} =~ /Cpanel\s+Ticket\s+System/i;    # Accounts like this are created by the autofixer2 create_temp_reseller_for_ticket_access script when cpanel support logs in

        my $userdata = Cpanel::WebServer::Userdata->new( user => $user );

        for my $vhost ( @{ $userdata->get_vhost_list() } ) {

            try {
                my $pkg = $userdata->get_vhost_lang_package( lang => $lang, vhost => $vhost );
                if ( $pkg ne "inherit" && !exists $installed{$pkg} ) {

                    # This PHP is no longer installed so set them to the default (their code may break but at least we ensure their source code is not served)
                    logger->info("User $user’s vhost “$vhost” is set to PHP “$pkg” which is no longer installed. Setting them to inherit …");
                    $apache->set_vhost_lang_package( userdata => $userdata, vhost => $vhost, lang => $lang, package => $default );
                    $userdata->set_vhost_lang_package( vhost => $vhost, lang => $lang, package => $default );
                }
            }
            catch {
                push @error, $_;
            };
        }
    }

    die Cpanel::Exception::create( 'Collection', [ exceptions => \@error ] ) if @error > 1;
    die $error[0]                                                            if @error == 1;

    return 1;
}

sub setup_session_save_path {
    require Cpanel::ProgLang::Supported::php::Ini;
    if ( Cpanel::ProgLang::Supported::php::Ini->can('setup_session_save_path') ) {
        my $rv = eval { Cpanel::ProgLang::Supported::php::Ini::setup_session_save_path() };
        return 2 if ref($@) eq "Cpanel::Exception::FeatureNotEnabled";    # ignore failures from PHP not being installed
        return $rv;
    }
    return;
}

unless ( caller() ) {
    my $cfg = get_php_config( \@ARGV );

    my $settings = get_rebuild_settings($cfg);
    apply_rebuild_settings( $cfg, $settings );
    setup_session_save_path();
}

1;

__END__

=encoding utf8

=head1 NAME

009-phpconf.pl -- package manager universal hook

=head1 SYNOPSIS

Executed by various package managers via this package: https://github.com/CpanelInc/yum-plugin-universal-hooks

=head1 DESCRIPTION

This scripts updates the cPanel and Apache MultiPHP configurations.  It's important
for this script to run after packages have been added, removed, or updated via the package manager
because the cPanel MultiPHP system depends on the configuration (default: /etc/cpanel/ea4/php.conf)
always being correct.

Some of the things it does are as follows:

=over 2

=item * If no PHP packages are installed on the system, it will remove all cPanel and Apache configuration information related to PHP.

It will leave users’ configurations as-is in case it was a temporary situation or a mistake. It also acts as a security benefit because they will get an error instead of the source code.

=item * If a PHP package is removed using the package manager, configuration for that package is removed.

Users assigned to it will be moved to the newest PHP installed.

This uses userdata for efficiency and reliability. It will not traverse the file system looking for C<.htaccess> files that have PHP looking handlers. That would be an expensive and fragile operation. As long as they use MultiPHP Manager (or CL’s PHP selector/cagefs system?) they will be in ship shape.

=item * If a PHP package is added using the package manager, a default configuration is applied.

=item * If an Apache handler for PHP is removed using the package manager, a default Apache handler is used instead.

=back

=head1 DEFAULT SYSTEM PACKAGE

If the default PHP package is removed, C<$cpanel_default_php_pkg> (AKA C<Cpanel::EA4::Util::get_default_php_version()>) is used if its installed. Otherwise the latest (according to PHP version number) is used.

=head1 APACHE HANDLER FOR PHP

If the Apache handler assigned to a PHP package is missing, the following checks are performed.
If a check succeeds, no further checks are performed.

=over 2

=item 1. Attempt to assign a package to the 'suphp' handler if the mod_suphp Apache module is installed.

=item 2. Attempt to assign a package to the 'dso' handler if the correct package is installed.

=over 2

=item * IMPORTANT NOTE: Only one 'dso' handler can be assigned at a time.

=back

=item 3. Attempt to assign a package to the Cpanel::EA4::Util::get_default_php_handler() (which if it is cgi, will work since the mod_cgi or mod_cgid Apache modules should be installed (and in the weird case it isn't then at leats they'll get errors instead of source code)).

=back

=head1 ADDITIONAL INFORMATION

This script depends on the packages setting up the correct dependencies and conflicts.  For
example, this script doesn't check the Apache configuration for MPM ITK when assigning PHP
to the SuPHP handler since it assumes the package should already have a conflict detected
by the package manager during installation.

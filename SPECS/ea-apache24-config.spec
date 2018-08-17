# This is the SPEC file that creates the RPM meta packages used
# by cPanel & WHM.  The RPMs should contain the configuration
# files, directory structures, and dependency tree needed to
# be compatible with cPanel & WHM devices.  You might consider
# this RPM package to be the "shim" that makes Apache and WHM
# work together.

%global ns_name  ea
%global pkg_name %{ns_name}-apache24-config

# do not produce empty debuginfo package
%global debug_package %{nil}

Summary:       Package that installs Apache 2.4 on CentOS 6
Name:          %{pkg_name}
Version:       1.0
# Doing release_prefix this way for Release allows for OBS-proof versioning, See EA-4546 for more details
%define release_prefix 134
Release: %{release_prefix}%{?dist}.cpanel
Group:         System Environment/Daemons
License:       Apache License 2.0
Vendor:        cPanel, Inc.
BuildArch:     noarch

Source0:       centos7_paths.conf
Source1:       centos6_paths.conf
Source2:       300-fixmailman.pl
Source3:       vhost.default
Source4:       ssl_vhost.default
Source5:       400-patch_mod_security2.pl
Source6:       010-purge_cache.pl
Source7:       500-restartsrv_httpd
Source8:       060-setup_apache_symlinks.pl
Source9:       070-cloudlinux-cagefs.pl
Source10:      ea4_main.default
Source11:      009-phpconf.pl
Source12:      generate-errordoc-conf
Source13:      011-modsec_cpanel_conf_init
Source14:      020-rebuild-httpdconf
Source15:      030-update-apachectl
Source17:      100-phpfpm_cleanup.pl
Source18:      520-enablefileprotect
Source19:      490-restartsrv_apache_php_fpm
Source20:      000-local_template_check
Source21:      010-suphpconf.pl
Source22:      011-migrate_extension_to_pecl_ini

BuildRoot:     %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Requires:      ea-webserver
Requires:      %{pkg_name}-runtime = %{version}
BuildRequires: perl-libwww-perl
BuildRequires: ea-apache24-devel

%description
This is the main package for Apache 2.4 on CentOS 6 for cPanel & WHM.

%package runtime
Summary:   Package that contains the cPanel & WHM integration data
Group:     System Environment/Daemons
Vendor:    cPanel, Inc.
License:   Apache License 2.0
Requires:  %{pkg_name} = %{version}
Requires:  yum-plugin-universal-hooks
AutoReq:   no
BuildArch: noarch
Requires:  perl-libwww-perl

%description runtime
Package shipping essential scripts/configurations to work with cPanel & WHM.

%install
rm -rf %{buildroot}
# NOTE: There isn't a (meta) RPM that owns /var/cpanel directory, so.. we
# gotta hardcode the path to this file without using a macro.  This also
# means that we won't be able to clean up after ourselves just yet.
mkdir -p %{buildroot}%{_localstatedir}/cpanel/templates/apache2_4
install %{SOURCE3} %{buildroot}%{_localstatedir}/cpanel/templates/apache2_4/vhost.default
install %{SOURCE4} %{buildroot}%{_localstatedir}/cpanel/templates/apache2_4/ssl_vhost.default
install %{SOURCE10} %{buildroot}%{_localstatedir}/cpanel/templates/apache2_4/ea4_main.default

mkdir -p $RPM_BUILD_ROOT/etc/cpanel/ea4
%if 0%{?rhel} >= 7
  install -m 644 %{SOURCE0} $RPM_BUILD_ROOT/etc/cpanel/ea4/paths.conf
%else
  install -m 644 %{SOURCE1} $RPM_BUILD_ROOT/etc/cpanel/ea4/paths.conf
%endif

mkdir -p $RPM_BUILD_ROOT%{_localstatedir}/log/apache2/domlogs

# Install the cache purge trigger
mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__
mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-php__WILDCARD__
mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-apache24-config
mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/__WILDCARD__-php__WILDCARD__
mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/pkgs/glibc/posttrans/
install %{SOURCE2}  $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/300-fixmailman.pl
install %{SOURCE6}  $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/010-purge_cache.pl
install %{SOURCE5}  $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/400-patch_mod_security2.pl
install %{SOURCE7}  $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/500-restartsrv_httpd
ln -sf %{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/500-restartsrv_httpd $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/pkgs/glibc/posttrans/100-glibc-restartsrv_httpd
install %{SOURCE8}  $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/060-setup_apache_symlinks.pl
install %{SOURCE9}  $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/070-cloudlinux-cagefs.pl
install %{SOURCE11} $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/__WILDCARD__-php__WILDCARD__/009-phpconf.pl
install %{SOURCE21} $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/__WILDCARD__-php__WILDCARD__/010-suphpconf.pl
install %{SOURCE11} $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/009-phpconf.pl
install %{SOURCE21} $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/010-suphpconf.pl
install %{SOURCE13} $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/011-modsec_cpanel_conf_init
install %{SOURCE14} $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/020-rebuild-httpdconf
install %{SOURCE15} $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/030-update-apachectl
install %{SOURCE18} $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/520-enablefileprotect
install %{SOURCE19} $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-php__WILDCARD__/490-restartsrv_apache_php_fpm
install %{SOURCE20} $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-apache24-config/000-local_template_check
install %{SOURCE22} $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-php__WILDCARD__/011-migrate_extension_to_pecl_ini

# For the PHP-FPM specific cleanup script
mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-php__WILDCARD__-php-fpm
install %{SOURCE17} $RPM_BUILD_ROOT%{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-php__WILDCARD__-php-fpm/100-phpfpm_cleanup.pl


# Install apache utility
%{__mkdir_p} %{buildroot}/%{_httpd_bindir}/
install %{SOURCE12} %{buildroot}/%{_httpd_bindir}/

# Create errordocument.conf for cpanel & whm product
%{__mkdir_p} %{buildroot}/%{_httpd_confdir}/includes
%{__perl} %{buildroot}/%{_httpd_bindir}/generate-errordoc-conf > %{buildroot}/%{_httpd_confdir}/includes/errordocument.conf

%clean
rm -rf %{buildroot}

%files

%files runtime
%defattr(0640,root,root,0755)
%attr(0644,root,root) /etc/cpanel/ea4/paths.conf
%dir %{_localstatedir}/cpanel/templates/apache2_4
%{_localstatedir}/cpanel/templates/apache2_4/*
%attr(0711,root,root) %dir %{_localstatedir}/log/apache2/domlogs
%attr(0755,root,root) %{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/__WILDCARD__-php__WILDCARD__/009-phpconf.pl
%attr(0755,root,root) %{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/__WILDCARD__-php__WILDCARD__/010-suphpconf.pl
%attr(0755,root,root) %{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/009-phpconf.pl
%attr(0755,root,root) %{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/010-suphpconf.pl
%attr(0755,root,root) %{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/010-purge_cache.pl
%attr(0755,root,root) %{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/011-modsec_cpanel_conf_init
%attr(0755,root,root) %{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/020-rebuild-httpdconf
%attr(0755,root,root) %{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/030-update-apachectl
%attr(0755,root,root) %{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/520-enablefileprotect
%attr(0755,root,root) %{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/060-setup_apache_symlinks.pl
%attr(0755,root,root) %{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/070-cloudlinux-cagefs.pl
%attr(0755,root,root) %{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/300-fixmailman.pl
%attr(0755,root,root) %{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/400-patch_mod_security2.pl
%attr(0755,root,root) %{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-php__WILDCARD__/490-restartsrv_apache_php_fpm
%attr(0755,root,root) %{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-php__WILDCARD__/011-migrate_extension_to_pecl_ini
%attr(0755,root,root) %{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-__WILDCARD__/500-restartsrv_httpd
%attr(0755,root,root) %{_sysconfdir}/yum/universal-hooks/pkgs/glibc/posttrans/100-glibc-restartsrv_httpd
%attr(0755,root,root) %{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-php__WILDCARD__-php-fpm/100-phpfpm_cleanup.pl
%attr(0755,root,root) %{_sysconfdir}/yum/universal-hooks/multi_pkgs/posttrans/ea-apache24-config/000-local_template_check
%attr(0755,root,root) %{_httpd_bindir}/generate-errordoc-conf
%config %attr(0640,root,root) %{_httpd_confdir}/includes/errordocument.conf

%changelog
* Wed Aug 15 2018 Tim Mullin <tim@cpanel.net> - 1.0-134
- EA-7012: Use hostname for proxy subdomains SSL vhost

* Thu Jul 26 2018 Rishwanth Yeddula <rish@cpanel.net> - 1.0-133
- EA-7777: Ensure that log entries for the hostname, and the shared IPs are
  logged in the main access_log instead of individual domlogs.

* Thu Jul 12 2018 Daniel Muey <dan@cpanel.net> - 1.0-132
- ZC-3914: Remove EA3 specific concurrent PHP open_basedir

* Thu Jun 07 2018 Rishwanth Yeddula <rish@cpanel.net> - 1.0-131
- EA-7548: Ensure that setup_session_save_path codepath properly executes in the YUM hook

* Mon May 21 2018 Daniel Muey <dan@cpanel.net> - 1.0-130
- EA-3773: paths.conf: use correct value for file_conf_mime_types

* Thu Apr 05 2018 Daniel Muey <dan@cpanel.net> - 1.0-129
- EA-7383: never automatically set to none

* Wed Apr 04 2018 Daniel Muey <dan@cpanel.net> - 1.0-128
- EA-7370: Have PHP config hook script error out if all PHPs would be set to `none`

* Mon Feb 26 2018 Daniel Muey <dan@cpanel.net> - 1.0-127
- EA-7252: Update migrate_extension_to_pecl_ini to use new INI file name

* Mon Feb 05 2018  Dan Muey <dan@cpanel.net> - 1.0-126
- ZC-3381: Ensure there is a newline after SSL hostname `</VirtualHost>`

* Thu Jan 11 2018 Rishwanth Yeddula <rish@cpanel.net> - 1.0-125
- ZC-3249: Ensure the "default SSL" vhost is properly bound to all of the
  shared IPs on the server. Additionally, fixed up the whitespace oddities
  in the generated vhost.

* Wed Dec 13 2017 Cory McIntire <cory@cpanel.net> - 1.0-124
- EA-6668: Update ea4_main.default to handle hostname SSL
- Update IPs list to only be a wildcard for hostname SSL

* Fri Dec 1 2017  J. Nick Koston <nick@cpanel.net> - 1.0-123
- EA-6986: Add global rewrite exclude to allow DCV when .well-known dirs are behind htaccess based password protection.

* Thu Nov 16 2017  J. Nick Koston <nick@cpanel.net> - 1.0-122
- EA-6962: Move global rewrite option 'inherit' definition before includes so that Global DCV rewrite isn't overridden by includes.

* Fri Nov 10 2017 Felipe Gasper <felipe@cpanel.net> - 1.0-121
- CPANEL-16347: Remove hostname from default proxy subdomain vhosts.

* Thu Nov 02 2017  Dan Muey <dan@cpanel.net> - 1.0-120
- EA-6910: move extension directives from php.ini to php.d/02-pecl.ini so it loads after 01-ioncube.ini

* Tue Oct 10 2017 Cory McIntire <cory@cpanel.net> 1.0-119
- EA-6793: whm-server-status triggers mod_sec

* Tue Oct 3 2017 Dan Muey <dan@cpanel.net> 1.0-118
- ZC-2930: Update ea4 vhost template for new ea4 WHM config options

* Fri Sep 22 2017 Jason Kiniry <jason@cpanel.net> 1.0-117
- Add an updated proxy subdomain vhost rewrite condition and a test for the conditions.

* Tue Sep 19 2017 Felipe Gasper <felipe@cpanel.net> 1.0-116
- Undo change from 1.0-115.

* Mon Sep 18 2017 Felipe Gasper <felipe@cpanel.net> 1.0-115
- COBRA-5581: Always use regexp to match SSL proxy subdomains in vhost.

* Thu Sep 14 2017 Dan Muey <dan@cpanel.net> 1.0-114
- EA-6808: restart apache when glibc is updated

* Wed Sep 13 2017 J. Nick Koston <nick@cpanel.net> 1.0-113
- EA-6778: Add warings to ssl_vhost.default about sslcertificatekeyfile

* Tue Sep 12 2017 Cory McIntire <cory@cpanel.net> 1.0-112
- EA-6240: Whitelist proxy subdomains in ModSec for SSL vhosts

* Fri Sep 1 2017 J. Nick Koston <nick@cpanel.net> 1.0-111
- EA-6733: Ensure .htaccess is read with mod_userdir and htaccess optimizations

* Thu Aug 10 2017 Felipe Gasper <felipe@cpanel.net> 1.0-110
- COBRA-5343: Don't include SSLCertificateKeyFile line if it isn't needed.

* Thu Aug 3 2017 Felipe Gasper <felipe@cpanel.net> 1.0-109
- EA-6548: Create directives for WebSocket over proxy subdomains.

* Thu Jul 13 2017 Dan Muey <dan@cpanel.net> 1.0-108
- EA-6536: undo EA-6159 since it interferes with some redirects

* Mon Jul 10 2017 Darren Mobley <darren@cpanel.net> 1.0-107
- HB-2719: remove trailing slash from fcgi alias config line in template

* Tue Jun 20 2017 Dan Muey <dan@cpanel.net> 1.0-106
- EA-6159: have fallback errordoc check for existence of .shtml file

* Fri Jun 16 2017 Rishwanth Yeddula <rish@cpanel.net> 1.0-105
- PIG-3252: Block userdir requests on mod_passenger

* Thu Jun 15 2017 Rishwanth Yeddula <rish@cpanel.net> 1.0-104
- PIG-3244: Set the proper PassengerUser and PassengerGroup per vhost to
  ensure that Passenger runs the applications as the right user.

* Tue Jun 13 2017 Dan Muey <dan@cpanel.net> 1.0-103
- EA-6414: Call PHP hook scripts for *-php* transactions

* Sun Jun 11 2017 Jacob Perkins <jacob.perkins@cpanel.net> - 1.0-102
- Reversion of CL modSec changes
- Removal of suphpconf.pl until fixes are in place.

* Fri Jun 09 2017 Jacob Perkins <jacob.perkins@cpanel.net> - 1.0-101
- Partial reversion of 009-phpconf.pl move

* Tue Jun 06 2017 Dan Muey <dan@cpanel.net> 1.0-100
- EA-6356: leave unknown suphp handlers in place

* Mon Jun 05 2017 Dan Muey <dan@cpanel.net> 1.0-99
- EA-6344: Add yum hook to ensure suphp.conf handlers are correct

* Thu Jun 01 2017 Dan Muey <dan@cpanel.net> 1.0-98
- EA-6246: ensure modescurity2's secdatadir/users dir cagefs entry (add % to 'lines matching' check)

* Mon May 29 2017 Dan Muey <dan@cpanel.net> 1.0-97
- EA-6324: Also call PHP config hook script after transactions with *-php*

* Mon May 22 2017 Cory McIntire <cory@cpanel.net> 1.0-96
- EA-6302: Add SSLStaplingResponderTimeout to help when OCSP is down

* Tue Apr 25 2017 Dan Muey <dan@cpanel.net> 1.0-95
- EA-6214: Add yum hook to notify .local users that the .default templates have changed

* Mon Apr 03 2017 Jared Wright <jared.wright@cpanel.net> 1.0-94
- STS-549: Setup php session directory after install of php.

* Thu Mar 30 2017 J. Nick Koston <nick@cpanel.net> - 1.0-93
- EA-6122: Ensure new style proxy subs are disabled if mod_proxy is not installed or proxy subdomains disabled

* Wed Mar 22 2017 Cory McIntire <cory@cpanel.net> - 1.0-92
- EA-6088: Bad regex in cPanel security policy httpd.conf addition

* Mon Mar 20 2017 J. Nick Koston <nick@cpanel.net> - 1.0-91
- EA-6082: Allow optimizing AllowOveride

* Sat Mar 11 2017 Cory McIntire <cory@cpanel.net> - 1.0.90
- EA-6026: Block exposure to .user.ini and php.ini in public_html

* Fri Mar 3 2017 Jacob Perkins <jacob.perkins@cpanel.net> - 1.0.89
- Hardened permissions for domlogs

* Wed Feb 22 2017 Nick Koston <nick@cpanel.net> - 1.0-88
- Add global DCV exclude to EA4 templates

* Wed Feb 22 2017 Jacob Perkins <jacob.perkins@cpanel.net> - 1.0-87
- EA-5983: Turn SSLStaplingFakeTryLater off in ea4 template

* Mon Feb 13 2017 Dan Muey <dan@cpanel.net> - 1.0-86
- EA-5864: Do not call restartsrv_apache_php_fpm on systems that do not have restartsrv_apache_php_fpm

* Tue Jan 21 2017 Dan Muey <dan@cpanel.net> - 1.0-85
- EA-5855: spork off fixmailman since it can take a while

* Thu Jan 19 2017 Nick Koston <nick@cpanel.net> - 1.0-84
- Remove extra tailing slash from ProxyPass subdomains (EA-5892)

* Thu Jan 19 2017 Nick Koston <nick@cpanel.net> - 1.0-83
- Update EA4 templates to support faster ProxyPass subdomains (EA-5860)

* Thu Jan 19 2017 Nick Koston <nick@cpanel.net> - 1.0-82
- Update EA4 templates for proxy subdomain AutoSSL support (EA-5859)

* Tue Dec 27 2016 Jacob Perkins <jacob.perkins@cpanel.net> - 1.0-81
- Send SSL traffic to only the SSL log

* Wed Dec 21 2016 Dan Muey <dan@cpanel.net> - 1.0-80
- EA-5783: Reload PHP-FPM after PHP modules are updated

* Fri Dec 16 2016 S. Kurt Newman <kurt.newman@cpanel.net> - 1.0-79
- This script only runs for 11.60.0.1 and newer (EA-5428)

* Wed Dec 07 2016 Dan Muey <dan@cpanel.net> - 1.0-78
- EA-5613: Remove ScriptAlias for no longer existing scgiwrap

* Tue Dec 06 2016 Dan Muey <dan@cpanel.net> - 1.0-77
- EA-5724: Allow splitlogs.conf to override the configured SSL port

* Thu Dec 01 2016 Dan Muey <dan@cpanel.net> - 1.0-76
- EA-5712: Remove 510-update-apachectl universal hook

* Tue Dec 01 2016 Edwin Buck <e.buck@cpanel.net> - 1.0-75
- EA-5533: Avoid crossing filesystems in location of pid file.

* Wed Nov 30 2016 Dan Muey <dan@cpanel.net> - 1.0-74
- EA-5658: Do hard restart of apache when mod_fcgid is involved in a transaction

* Tue Nov 01 2016 Edwin Buck <e.buck@cpanel.net> - 1.0-73
- EA-5484: Add support for SymlinkProtect in httpd.conf templates.

* Wed Oct 26 2016 Darren Mobley <darren@cpanel.net> - 1.0-72
- HB-2037: Fix shebang in fileprotect script

* Thu Oct 25 2016 Dan Muey <dan@cpanel.net> - 1.0-71
- EA-4922: Have 009 use new interface to determine availability of handler

* Mon Oct 18 2016 Mark Gardner <m.gardner@cpanel.net> - 1.0-70
- HB-1985: add enablefileprotect hook based on existence of touchfile

* Wed Sep 21 2016 Dan Muey <dan@cpanel.net> - 1.0-69
- ZC-2149: restore the proxy subdomain comments to where the parser needs them to be

* Fri Sep 16 2016 Darren Mobley <darren@cpanel.net> - 1.0-68
- HB-1952: Add posttrans script to clean upand reset to default the PHP
  configurations for users using FPM when the packages are removed.

* Tue Sep 13 2016 Dan Muey <dan@cpanel.net> - 1.0-67
- EA-5227: improve output of symlink setup script

* Tue Aug 23 2016 Edwin Buck <e.buck@cpanel.net> 1.0-66
- EA-4914: Fix PHP installations to not report module removals.

* Mon Aug 08 2016 Matt Dees <matt.dees@cpanel.net> 1.0-65
- CPANEL-7006: Make fpm pools use SetHandler rather than ProxyPassMatch

* Fri Jul 15 2016 Edwin Buck <e.buck@cpanel.net> - 1.0-64
- EA-4684: Disable mod_security restritions on proxy vhost traffic

* Thu Jul 14 2016 Dan Muey <dan@cpanel.net> - 1.0-63
- ZC-1972: Have 009 script default PHP to 5.6

* Tue Jul 05 2016 Edwin Buck <e.buck@cpanel.net> - 1.0-62
- EA-4673: Rollback modsec2 location change until WHM can support it.

* Tue Jul 05 2016 S. Kurt Newman <kurt.newman@cpanel.net> - 1.0-61
- Now fixes permissions on mailman dir in case Apache env changes (ZC-2011)

* Thu Jun 30 2016 Dan Muey <dan@cpanel.net> - 1.0-60
- ZC-2014: Make sure modsec conf is initialized via universal hook

* Mon Jun 20 2016 Dan Muey <dan@cpanel.net> - 1.0-59
- EA-4383: Update Release value to OBS-proof versioning

* Fri Jun 3 2016 David Nielson <david.nielson@cpanel.net> 1.0-48
- Recognize libphp7.so as a valid PHP handler

* Mon May 16 2016 Julian Brown <julian.brown@cpanel.net> 1.0.47
- Add templates to vhost for PHP-FPM.

* Wed Apr 20 2016 Jacob Perkins <jacob.perkins@cpanel.net> 1.0.46
- Disable stabling errors from being sent to the HTTP client.

* Fri Feb 12 2016  Darren Mobley <darren@cpanel.net> 1.0.45
- Removed call to clear packman cache

* Tue Dec 22 2015  Dan Muey <dan@cpanel.net> 1.0.44
- Do splitlogs.conf logic in template

* Wed Dec 17 2015 Dan Muey <dan@cpanel.net> 1.0.43
- configure split logs when its enabled

* Thu Dec 17 2015 S. Kurt Newman <kurt.newman@cpanel.net> - 1.0.42
- Fixed virtual host definition ordering httpd.conf so users
  can override cpanel & whm proxy subdomains (EA-3865)

* Tue Dec 15 2015 Dan Muey <dan@cpanel.net> 1.0.41
- Add PackMan cache to 010-purge_cache.pl

* Mon Dec 07 2015 Dan Muey <dan@cpanel.net> 1.0.40
- Update name space and attribute (ZC-1202)

* Thu Nov 12 2015 Dan Muey <dan@cpanel.net> 1.0.39
- Have 009-phpconf.pl work under the original and refactored MultiPHP modules

* Thu Oct 01 2015 Dan Muey <dan@cpanel.net> 1.0.38
- Remove legacy mod_disable_suexec logic from SSL

* Thu Oct  1 2015 S. Kurt Newman <kurt.newman@cpanel.net> - 1.0-37
- Now allows cpanel users to customize their error pages using
  errordocument.conf (EA-3732)

* Wed Sep 30 2015 Dan Muey <dan@cpanel.net> 1.0.36
- Remove legacy mod_disable_suexec logic

* Fri Sep 01 2015 S. Kurt Newman <kurt.newman@cpanel.net> 1.0-35
- Fix for changelog to get OBS to publish correctly

* Fri Sep 01 2015 S. Kurt Newman <kurt.newman@cpanel.net> 1.0-34
- Updated ea4_main.default with a host of fixes (ZC-913 for more info)
- Changed package to noarch

* Tue Sep 01 2015 Julian Brown <julian.brown@cpanel.net> 1.0-33
- Have phpconf fix up happen earlier in the process.

* Mon Aug 24 2015 Dan Muey <dan@cpanel.net> 1.0-32
- Update template to work with errordocument.conf

* Fri Aug 21 2015 Trinity Quirk <trinity.quirk@cpanel.net> 1.0-31
- Added checking in php hook that sysdefault is still installed

* Mon Aug 17 2015 Trinity Quirk <trinity.quirk@cpanel.net> 1.0-30
- Added cgi fallback to phpconf hook when suphp is not available

* Mon Aug 17 2015 Darren Mobley <darren@cpanel.net> 1.0-29
- Remove handling of /etc/cpanel/ea4/is_ea4

* Thu Aug 13 2015 Dan Muey <dan@cpanel.net> 1.0-28
- have PHP config hook script account for a zero PHP state: ignore needless object constructor death and remove its files

* Tue Jun 30 2015 S. Kurt Newman <kurt.newman@cpanel.net> 1.0-27
- Removed unused Apache templates

* Thu Jun 25 2015 Darren Mobley <darren@cpanel.net> 1.0-26
- Added rlimitmem and rlimitcpu options to the ea4_main template

* Wed Jun 05 2015 Julian Brown <julian.brown@cpanel.net> 1.0-25
- Moved 050-update-apachectl to 510-update-apachectl

* Wed Jun 03 2015 Darren Mobley <darren@cpanel.net> 1.0-24
- Renamed 040-restartsrv_httpd.sh to 500-restartsrv_httpd.sh to fix chicken/egg problem during migration

* Thu May 28 2015 Darren Mobley <darren@cpanel.net> 1.0-23
- Renamed package to ea-apache24-config for granularity

* Mon May 11 2015 Darren Mobley <darren@cpanel.net> 1.0-22
- Renamed spec file itself to ea-apache2-config.spec

* Mon May 07 2015 Darren Mobley <darren@cpanel.net> 1.0-21
- Renamed to ea-apache2-config

* Wed May 06 2015 Dan Muey <dan@cpanel.net> - 1.0-20
- update name of yum-plugin

* Wed May 06 2015 Dan Muey <dan@cpanel.net> - 1.0-19
- Update license from cpanel to BSD 2-Clause
- add comment to 040 exlaining why it isn't a symlink

* Wed May 06 2015 Julian Brown <julian.brown@cpanel.net> - 1.0-18
- Modified template to include CustomLogs

* Tue May 05 2015 Dan Muey <dan@cpanel.net> - 1.0-17
- Added TypesConfig for mime types to the template for Apache 2.4

* Tue Apr 28 2015 Dan Muey <dan@cpanel.net> - 1.0-16
- Put paths.conf & is_ea4 in /etc/cpanel/ea4 for non-root users

* Tue Apr 01 2015 Dan Muey <dan@cpanel.net> - 1.0-15
- Updated 080 script to not use method that was removed upstream

* Mon Mar 30 2015 Dan Muey <dan@cpanel.net> - 1.0-14
- Added 080-phpconf script

* Mon Mar 30 2015 Dan Muey <dan@cpanel.net> - 1.0-13
- Fixed 060 to not symlink conf dir (specific content already symlinked)
- consolidated 060's mkdirs and fixed bug w/ error variable

* Tue Mar 24 2015 Trinity Quirk <trinity.quirk@cpanel.net> 1.0-12
- Added ea4_main template, and pointed things back to httpd.conf

* Mon Mar 23 2015 Tim Mullin <tim@cpanel.net> 1.0-11
- Added symlink script

* Mon Mar 23 2015 Trinity Quirk <trinity.quirk@cpanel.net> 1.0-10
- Renamed to ea-httpd*

* Fri Mar 20 2015  Tim Mullin <tim@cpanel.net> 1.0-9
- Stopped autogenerating "requires" for httpd-runtime
- Invoking restartsrv_http via a script rather than a symlink

* Thu Mar 19 2015  Tim Mullin <tim@cpanel.net> 1.0-8
- Added symlinked triggers for apache

* Wed Mar 18 2015  Dan Muey <dan@cpanel.net> - 1.0-7
- Added the cloudlinux cagefs yum plugin script

* Wed Mar 18 2015 Tim Mullin <tim@cpanel.net> - 1.0-6
- Added the cache purge yum plugin script
- bump version for release

* Tue Mar 17 2015 Dan Muey <dan@cpanel.net> - 1.0-5
- changed indicator file from conf_dir/ea4_built to /var/cpanel/conf/is_ea4
- bump version for release

* Fri Feb 27 2015 Trinity Quirk <trinity.quirk@cpanel.net> - 1.0-3
- Changed package name to httpd
- Updated paths.conf to reflect new filesystem layout

* Thu Feb 26 2015 Trinity Quirk <trinity.quirk@cpanel.net> - 1.0-2
- Added cPanel config templates
- Added dependency on httpd-mpm

* Wed Feb 18 2015 Matt Dees <matt.dees@cpanel.net> - 1.0-1
- add ea4_built flag file

* Tue Jan 20 2015 S. Kurt Newman <kurt.newman@cpanel.net> - 1.0-0
- Initial creation

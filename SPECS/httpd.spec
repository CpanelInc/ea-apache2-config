# This is the SPEC file that creates the RPM meta packages used
# by cPanel & WHM.  The RPMs should contain the configuration
# files, directory structures, and dependency tree needed to
# be compatible with cPanel & WHM devices.  You might consider
# this RPM package to be the "shim" that makes Apache and WHM
# work together.

%global pkg_name httpd

# do not produce empty debuginfo package
%global debug_package %{nil}

Summary:       Package that installs Apache 2.4 on CentOS 6
Name:          %{pkg_name}
Version:       1.0
Release:       8%{?dist}
Group:         System Environment/Daemons
License:       Apache License 2.0
Vendor:        cPanel, Inc.

Source0:       paths.conf
Source1:       cpanel.default
Source2:       vhosts.default
Source3:       vhost.default
Source4:       ssl_vhost.default
Source5:       is_ea4
Source6:       010-purge_cache.pl
Source7:       070-cloudlinux-cagefs.pl

BuildRoot:     %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Requires:      yum-plugin-cpanel
Requires:      ea-webserver
Requires:      %{pkg_name}-runtime = %{version}

%description
This is the main package for Apache 2.4 on CentOS 6 for cPanel & WHM.

%package runtime
Summary:   Package that contains the cPanel & WHM integration data
Group:     System Environment/Daemons
Vendor:    cPanel, Inc.
License:   Apache License 2.0
Requires:  %{pkg_name} = %{version}

%description runtime
Package shipping essential scripts/configurations to work with cPanel & WHM.

%install
rm -rf %{buildroot}
# NOTE: There isn't a (meta) RPM that owns /var/cpanel directory, so.. we
# gotta hardcode the path to this file without using a macro.  This also
# means that we won't be able to clean up after ourselves just yet.
install -D %{SOURCE0} %{buildroot}%{_localstatedir}/cpanel/conf/apache/paths.conf
install -D %{SOURCE1} %{buildroot}%{_localstatedir}/cpanel/templates/apache2_4/cpanel.default
install %{SOURCE2} %{buildroot}%{_localstatedir}/cpanel/templates/apache2_4/vhosts.default
install %{SOURCE3} %{buildroot}%{_localstatedir}/cpanel/templates/apache2_4/vhost.default
install %{SOURCE4} %{buildroot}%{_localstatedir}/cpanel/templates/apache2_4/ssl_vhosts.default

# place is_ea4
mkdir -p $RPM_BUILD_ROOT/var/cpanel/conf
install -m 644 %{SOURCE5} $RPM_BUILD_ROOT/var/cpanel/conf/is_ea4

mkdir -p $RPM_BUILD_ROOT%{_localstatedir}/log/apache2/domlogs

# Install the cache purge trigger
mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__
install -m 755 %{SOURCE6} $RPM_BUILD_ROOT%{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/010-purge_cache.pl
ln -sf /usr/local/cpanel/scripts/rebuildhttpdconf $RPM_BUILD_ROOT%{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/020-rebuild-httpdconf
ln -sf /usr/local/cpanel/scripts/update_apachectl $RPM_BUILD_ROOT%{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/030-update-apachectl
ln -sf /usr/local/cpanel/scripts/restartsrv_httpd $RPM_BUILD_ROOT%{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/040-restart-httpd
ln -sf /usr/local/cpanel/scripts/update_apachectl $RPM_BUILD_ROOT%{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/050-update-apachectl
# 060-symlink-setup will go here - to be done in HB-313
install -m 755 %{SOURCE7} $RPM_BUILD_ROOT%{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/070-cloudlinux-cagefs.pl

%clean
rm -rf %{buildroot}

%files

%files runtime
%defattr(0640,root,root,0755)
%{_localstatedir}/cpanel/conf/apache/paths.conf
%dir %{_localstatedir}/cpanel/templates/apache2_4
%{_localstatedir}/cpanel/templates/apache2_4/*
/var/cpanel/conf/is_ea4
%dir %{_localstatedir}/log/apache2/domlogs
%attr(0755,root,root) %{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/010-purge_cache.pl
%attr(0755,root,root) %{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/020-rebuild-httpdconf
%attr(0755,root,root) %{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/030-update-apachectl
%attr(0755,root,root) %{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/040-restart-httpd
%attr(0755,root,root) %{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/050-update-apachectl
%attr(0755,root,root) %{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/070-cloudlinux-cagefs.pl

%changelog
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

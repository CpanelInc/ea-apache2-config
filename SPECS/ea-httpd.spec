# This is the SPEC file that creates the RPM meta packages used
# by cPanel & WHM.  The RPMs should contain the configuration
# files, directory structures, and dependency tree needed to
# be compatible with cPanel & WHM devices.  You might consider
# this RPM package to be the "shim" that makes Apache and WHM
# work together.

%global ns_name  ea
%global pkg_name %{ns_name}-httpd

# do not produce empty debuginfo package
%global debug_package %{nil}

Summary:       Package that installs Apache 2.4 on CentOS 6
Name:          %{pkg_name}
Version:       1.0
Release:       18%{?dist}
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
Source7:       040-restartsrv_httpd.sh
Source8:       060-setup_apache_symlinks.pl
Source9:       070-cloudlinux-cagefs.pl
Source10:      ea4_main.default
Source11:      080-phpconf.pl

BuildRoot:     %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
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
Requires:  yum-plugin-cpanel
AutoReq:   no

%description runtime
Package shipping essential scripts/configurations to work with cPanel & WHM.

%install
rm -rf %{buildroot}
# NOTE: There isn't a (meta) RPM that owns /var/cpanel directory, so.. we
# gotta hardcode the path to this file without using a macro.  This also
# means that we won't be able to clean up after ourselves just yet.
install -D %{SOURCE1} %{buildroot}%{_localstatedir}/cpanel/templates/apache2_4/cpanel.default
install %{SOURCE2} %{buildroot}%{_localstatedir}/cpanel/templates/apache2_4/vhosts.default
install %{SOURCE3} %{buildroot}%{_localstatedir}/cpanel/templates/apache2_4/vhost.default
install %{SOURCE4} %{buildroot}%{_localstatedir}/cpanel/templates/apache2_4/ssl_vhosts.default
install %{SOURCE10} %{buildroot}%{_localstatedir}/cpanel/templates/apache2_4/ea4_main.default

# place is_ea4
mkdir -p $RPM_BUILD_ROOT/etc/cpanel/ea4
install -m 644 %{SOURCE5} $RPM_BUILD_ROOT/etc/cpanel/ea4/is_ea4
install -m 644 %{SOURCE0} $RPM_BUILD_ROOT/etc/cpanel/ea4/paths.conf

mkdir -p $RPM_BUILD_ROOT%{_localstatedir}/log/apache2/domlogs

# Install the cache purge trigger
mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__
install -m 755 %{SOURCE6} $RPM_BUILD_ROOT%{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/010-purge_cache.pl
ln -sf /usr/local/cpanel/scripts/rebuildhttpdconf $RPM_BUILD_ROOT%{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/020-rebuild-httpdconf
ln -sf /usr/local/cpanel/scripts/update_apachectl $RPM_BUILD_ROOT%{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/030-update-apachectl
install -m 755 %{SOURCE7} $RPM_BUILD_ROOT%{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/040-restartsrv_httpd.sh
ln -sf /usr/local/cpanel/scripts/update_apachectl $RPM_BUILD_ROOT%{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/050-update-apachectl
install -m 755 %{SOURCE8} $RPM_BUILD_ROOT%{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/060-setup_apache_symlinks.pl
install -m 755 %{SOURCE9} $RPM_BUILD_ROOT%{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/070-cloudlinux-cagefs.pl
install -m 755 %{SOURCE11} $RPM_BUILD_ROOT%{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/080-phpconf.pl

%clean
rm -rf %{buildroot}

%files

%files runtime
%defattr(0640,root,root,0755)
/etc/cpanel/ea4/paths.conf
%dir %{_localstatedir}/cpanel/templates/apache2_4
%{_localstatedir}/cpanel/templates/apache2_4/*
/etc/cpanel/ea4/is_ea4
%dir %{_localstatedir}/log/apache2/domlogs
%attr(0755,root,root) %{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/010-purge_cache.pl
%attr(0755,root,root) %{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/020-rebuild-httpdconf
%attr(0755,root,root) %{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/030-update-apachectl
%attr(0755,root,root) %{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/040-restartsrv_httpd.sh
%attr(0755,root,root) %{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/050-update-apachectl
%attr(0755,root,root) %{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/060-setup_apache_symlinks.pl
%attr(0755,root,root) %{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/070-cloudlinux-cagefs.pl
%attr(0755,root,root) %{_sysconfdir}/yum/cpanel/multi_pkgs/posttrans/ea-__WILDCARD__/080-phpconf.pl

%changelog
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

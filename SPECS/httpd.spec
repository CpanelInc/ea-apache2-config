# This is the SPEC file that creates the RPM meta packages used
# by cPanel & WHM.  The RPMs should contain the configuration
# files, directory structures, and dependency tree needed to
# be compatible with cPanel & WHM devices.  You might consider
# this RPM package to be the "shim" that makes Apache and WHM
# work together.

%global pkg_name httpd24

# do not produce empty debuginfo package
%global debug_package %{nil}

Summary:       Package that installs Apache 2.4 on CentOS 6
Name:          %{pkg_name}
Version:       1.0
Release:       2%{?dist}
Group:         System Environment/Daemons
License:       Apache License 2.0
Vendor:        cPanel, Inc.

Source0:       paths.conf
Source1:       cpanel.default
Source2:       vhosts.default
Source3:       vhost.default
Source4:       ssl_vhost.default
Source5:       ea4_built

BuildRoot:     %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
Requires:      httpd
Requires:      httpd-mpm
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
install -D %{SOURCE0} %{buildroot}/var/cpanel/conf/apache/paths.conf
install -D %{SOURCE1} %{buildroot}/var/cpanel/templates/apache2_4/cpanel.default
install %{SOURCE2} %{buildroot}/var/cpanel/templates/apache2_4/vhosts.default
install %{SOURCE3} %{buildroot}/var/cpanel/templates/apache2_4/vhost.default
install %{SOURCE4} %{buildroot}/var/cpanel/templates/apache2_4/ssl_vhosts.default

# place ea4_built.conf
mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/httpd/conf.d/ea4_built
install -m 644 $RPM_SOURCE_DIR/ea4_built \
    $RPM_BUILD_ROOT%{_sysconfdir}/httpd/conf.d/ea4_built

%clean
rm -rf %{buildroot}

%files

%files runtime
%defattr(0640,root,root,0755)
/var/cpanel/conf/apache/paths.conf
/var/cpanel/templates/apache2_4/*
/etc/httpd/conf.d/ea4_built

%changelog
* Thu Feb 26 2015 Trinity Quirk <trinity.quirk@cpanel.net> - 1.0-2
- Added cPanel config templates
- Added dependency on httpd-mpm

* Wed Feb 18 2015 Matt Dees <matt.dees@cpanel.net> - 1.0-1
- add ea4_built flag file

* Tue Jan 20 2015 S. Kurt Newman <kurt.newman@cpanel.net> - 1.0-0
- Initial creation

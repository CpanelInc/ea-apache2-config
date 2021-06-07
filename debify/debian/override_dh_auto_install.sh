#!/bin/bash

set -x 
source debian/vars.sh

# NOTE: There isn't a (meta) package that owns /var/cpanel directory, so.. we
# gotta hardcode the path to this file without using a macro.  This also
# means that we won't be able to clean up after ourselves just yet.
mkdir -p $buildroot$_localstatedir/cpanel/templates/apache2_4
install $SOURCE3 $buildroot$_localstatedir/cpanel/templates/apache2_4/vhost.default
install $SOURCE4 $buildroot$_localstatedir/cpanel/templates/apache2_4/ssl_vhost.default
install $SOURCE10 $buildroot$_localstatedir/cpanel/templates/apache2_4/ea4_main.default
mkdir -p $DEB_INSTALL_ROOT/etc/cpanel/ea4
install -m 644 $SOURCE0 $DEB_INSTALL_ROOT/etc/cpanel/ea4/paths.conf
mkdir -p $DEB_INSTALL_ROOT$_localstatedir/log/apache2/domlogs
# Install the cache purge trigger
mkdir -p $hooks_base/ea-__WILDCARD__
mkdir -p $hooks_base/ea-php__WILDCARD__
mkdir -p $hooks_base/ea-apache24-config
mkdir -p $hooks_base/__WILDCARD__-php__WILDCARD__
mkdir -p $DEB_INSTALL_ROOT$_sysconfdir/apt/universal-hooks/pkgs/glibc/Post-Invoke/
install $SOURCE2  $hooks_base/ea-__WILDCARD__/300-fixmailman.pl
install $SOURCE6  $hooks_base/ea-__WILDCARD__/010-purge_cache.pl
install $SOURCE5  $hooks_base/ea-__WILDCARD__/400-patch_mod_security2.pl
install $SOURCE7  $hooks_base/ea-__WILDCARD__/500-restartsrv_httpd
install $SOURCE24 $hooks_base/ea-__WILDCARD__/001-ensure-nobody

ln -sf  $hooks_base_sys/ea-__WILDCARD__/500-restartsrv_httpd $DEB_INSTALL_ROOT$_sysconfdir/apt/universal-hooks/pkgs/glibc/Post-Invoke/100-glibc-restartsrv_httpd
install $SOURCE8  $hooks_base/ea-__WILDCARD__/060-setup_apache_symlinks.pl
install $SOURCE9  $hooks_base/ea-__WILDCARD__/070-cloudlinux-cagefs.pl
install $SOURCE11 $hooks_base/__WILDCARD__-php__WILDCARD__/009-phpconf.pl
install $SOURCE21 $hooks_base/__WILDCARD__-php__WILDCARD__/010-suphpconf.pl
install $SOURCE11 $hooks_base/ea-__WILDCARD__/009-phpconf.pl
install $SOURCE21 $hooks_base/ea-__WILDCARD__/010-suphpconf.pl
install $SOURCE13 $hooks_base/ea-__WILDCARD__/011-modsec_cpanel_conf_init
install $SOURCE14 $hooks_base/ea-__WILDCARD__/020-rebuild-httpdconf
install $SOURCE15 $hooks_base/ea-__WILDCARD__/030-update-apachectl
install $SOURCE18 $hooks_base/ea-__WILDCARD__/520-enablefileprotect
install $SOURCE19 $hooks_base/ea-php__WILDCARD__/490-restartsrv_apache_php_fpm
install $SOURCE20 $hooks_base/ea-apache24-config/000-local_template_check
install $SOURCE22 $hooks_base/ea-php__WILDCARD__/011-migrate_extension_to_pecl_ini
# For the PHP-FPM specific cleanup script
mkdir -p $hooks_base/ea-php__WILDCARD__-php-fpm
install $SOURCE17 $hooks_base/ea-php__WILDCARD__-php-fpm/100-phpfpm_cleanup.pl
# Install apache utility
mkdir -p $buildroot/$_httpd_bindir/
install $SOURCE12 $buildroot/$_httpd_bindir/
# Create errordocument.conf for cpanel & whm product
mkdir -p $buildroot/$_httpd_confdir/includes
$perl  $buildroot/$_httpd_bindir/generate-errordoc-conf > $buildroot/$_httpd_confdir/includes/errordocument.conf
install $SOURCE23 $buildroot/$_httpd_confdir/

# I tried very hard to use adjust_install_file_src, but it would not work
mkdir -p debian/tmp/etc/apt/universal-hooks/pkgs/glibc/Post-Invoke
ln -sf $hooks_base_sys/ea-__WILDCARD__/500-restartsrv_httpd debian/tmp/etc/apt/universal-hooks/pkgs/glibc/Post-Invoke/100-glibc-restartsrv_httpd

mkdir -p debian/tmp/var/cpanel/log/apache2/domlogs


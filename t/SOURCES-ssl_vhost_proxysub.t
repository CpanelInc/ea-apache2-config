#!/usr/local/cpanel/3rdparty/bin/perl -w

# cpanel - t/SOURCES-ssl_vhost_proxysub.t            Copyright 2017 cPanel, Inc.
#                                                           All rights Reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

package t::SOURCES_ssl_vhost_proxysub;

use strict;
use warnings;
use autodie;

use Try::Tiny;

use FindBin;
use lib "$FindBin::Bin/../SOURCES/whostmgr-plugin/perl/", "$FindBin::Bin/lib", qw( /usr/local/cpanel/ /usr/local/cpanel/t/lib );

use parent qw(
  Cpanel::TestObj::TempFile
);

use Test::More;
use Test::NoWarnings;
use Test::Deep;
use Test::Trap;
use Test::Exception;
use Test::Warn;

use Cwd ();

use Cpanel::JSON           ();
use Cpanel::Template       ();
use Cpanel::WildcardDomain ();

if ( !caller ) {
    my $test_obj = __PACKAGE__->new();
    plan tests => $test_obj->expected_tests(+1);
    $test_obj->runtests();
}

#----------------------------------------------------------------------

sub test_ssl_vhost_proxy_rewritecond : Test(4) {
    my ($self) = @_;

    my $json     = do { local $/; <DATA>; };
    my $input_hr = Cpanel::JSON::Load($json);

    my $tempdir = $self->tempdir();

    $input_hr->{'wildcard_safe'}         = \&Cpanel::WildcardDomain::encode_wildcard_domain;
    $input_hr->{'legacy_wildcard_safe'}  = \&Cpanel::WildcardDomain::encode_legacy_wildcard_domain;
    $input_hr->{'includes'}{'ssl_vhost'} = Cwd::abs_path("$FindBin::Bin/../SOURCES/ssl_vhost.default");
    $input_hr->{'includes'}{'vhost'}     = Cwd::abs_path("$FindBin::Bin/../SOURCES/vhost.default");
    $input_hr->{'template_file'}         = Cwd::abs_path("$FindBin::Bin/../SOURCES/ea4_main.default");

    local $Cpanel::Template::Files::tmpl_dir        = $tempdir;
    local $Cpanel::Template::Files::tmpl_source_dir = $tempdir;
    my ( $status, $output ) = Cpanel::Template::process_template( "apache2_4", $input_hr, { 'skip_local' => 1 } );

    ok( $status, 'Template processed ok!' ) or note explain [ $status, $output ];

    # This currently has to remove the [OR] at the end of the conditions too as they are applied in hash order
    my $lines_ar = _get_rewritecond_lines($output);

    # This isn't a great test, but it checks for what we added (mostly) for now
    # TODO: Improve this test

    cmp_bag(
        $lines_ar,
        [
            'RewriteCond %{REQUEST_URI} ^/\\.well-known/pki-validation/(?:\\ Ballot169)?',
            'RewriteCond %{REQUEST_URI} ^/\\.well-known/cpanel-dcv/[0-9a-zA-Z_-]+$',
            'RewriteCond %{REQUEST_URI} ^/\\.well-known/pki-validation/[A-F0-9]{32}\\.txt(?:\\ QAPortal\\ DCV)?$',
            'RewriteCond %{REQUEST_URI} ^/\\.well-known/pki-validation/[A-F0-9]{32}\\.txt(?:\\ Sectigo\\ DCV)?$',
            'RewriteCond %{HTTP_HOST} !^(?:autoconfig|autodiscover|cpanel|cpcalendars|cpcontacts|webdisk|webmail|whm)\\.',
            'RewriteCond %{HTTP_HOST} =autodiscover.mock.server.tld',
            'RewriteCond %{HTTP_HOST} =autodiscover.mock.server.tld:443',
            'RewriteCond %{HTTP:Upgrade} !websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} =cpanel.mock.server.tld',
            'RewriteCond %{HTTP_HOST} =cpanel.mock.server.tld:443',
            'RewriteCond %{HTTP:Upgrade} !websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} =webdisk.mock.server.tld',
            'RewriteCond %{HTTP_HOST} =webdisk.mock.server.tld:443',
            'RewriteCond %{HTTP:Upgrade} !websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} =webmail.mock.server.tld',
            'RewriteCond %{HTTP_HOST} =webmail.mock.server.tld:443',
            'RewriteCond %{HTTP:Upgrade} !websocket   [nocase]',
            'RewriteCond %{HTTP:Upgrade} websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} =cpanel.mock.server.tld',
            'RewriteCond %{HTTP_HOST} =cpanel.mock.server.tld:443',
            'RewriteCond %{HTTP:Upgrade} websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} =webmail.mock.server.tld',
            'RewriteCond %{HTTP_HOST} =webmail.mock.server.tld:443',
            'RewriteCond %{HTTP_HOST} =autodiscover.lawfulevil.tld',
            'RewriteCond %{HTTP_HOST} =autodiscover.lawfulevil.tld:443',
            'RewriteCond %{HTTP_HOST} =autodiscover.neutralevil.tld',
            'RewriteCond %{HTTP_HOST} =autodiscover.neutralevil.tld:443',
            'RewriteCond %{HTTP:Upgrade} !websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} =cpanel.lawfulevil.tld',
            'RewriteCond %{HTTP_HOST} =cpanel.lawfulevil.tld:443',
            'RewriteCond %{HTTP_HOST} =cpanel.neutralevil.tld',
            'RewriteCond %{HTTP_HOST} =cpanel.neutralevil.tld:443',
            'RewriteCond %{HTTP:Upgrade} !websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} =webdisk.lawfulevil.tld',
            'RewriteCond %{HTTP_HOST} =webdisk.lawfulevil.tld:443',
            'RewriteCond %{HTTP_HOST} =webdisk.neutralevil.tld',
            'RewriteCond %{HTTP_HOST} =webdisk.neutralevil.tld:443',
            'RewriteCond %{HTTP:Upgrade} !websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} =webmail.lawfulevil.tld',
            'RewriteCond %{HTTP_HOST} =webmail.lawfulevil.tld:443',
            'RewriteCond %{HTTP_HOST} =webmail.neutralevil.tld',
            'RewriteCond %{HTTP_HOST} =webmail.neutralevil.tld:443',
            'RewriteCond %{HTTP:Upgrade} !websocket   [nocase]',
            'RewriteCond %{HTTP:Upgrade} websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} =cpanel.lawfulevil.tld',
            'RewriteCond %{HTTP_HOST} =cpanel.lawfulevil.tld:443',
            'RewriteCond %{HTTP_HOST} =cpanel.neutralevil.tld',
            'RewriteCond %{HTTP_HOST} =cpanel.neutralevil.tld:443',
            'RewriteCond %{HTTP:Upgrade} websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} =webmail.lawfulevil.tld',
            'RewriteCond %{HTTP_HOST} =webmail.lawfulevil.tld:443',
            'RewriteCond %{HTTP_HOST} =webmail.neutralevil.tld',
            'RewriteCond %{HTTP_HOST} =webmail.neutralevil.tld:443',
            'RewriteCond %{HTTP_HOST} =autodiscover.whm.tld',
            'RewriteCond %{HTTP_HOST} =autodiscover.whm.tld:443',
            'RewriteCond %{HTTP:Upgrade} !websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} =cpanel.whm.tld',
            'RewriteCond %{HTTP_HOST} =cpanel.whm.tld:443',
            'RewriteCond %{HTTP:Upgrade} !websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} =webdisk.whm.tld',
            'RewriteCond %{HTTP_HOST} =webdisk.whm.tld:443',
            'RewriteCond %{HTTP:Upgrade} !websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} =webmail.whm.tld',
            'RewriteCond %{HTTP_HOST} =webmail.whm.tld:443',
            'RewriteCond %{HTTP:Upgrade} !websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} =whm.whm.tld',
            'RewriteCond %{HTTP_HOST} =whm.whm.tld:443',
            'RewriteCond %{HTTP:Upgrade} !websocket   [nocase]',
            'RewriteCond %{HTTP:Upgrade} websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} =cpanel.whm.tld',
            'RewriteCond %{HTTP_HOST} =cpanel.whm.tld:443',
            'RewriteCond %{HTTP:Upgrade} websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} =webmail.whm.tld',
            'RewriteCond %{HTTP_HOST} =webmail.whm.tld:443',
            'RewriteCond %{HTTP:Upgrade} websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} =whm.whm.tld',
            'RewriteCond %{HTTP_HOST} =whm.whm.tld:443',
            'RewriteCond %{REQUEST_URI} ^/\\.well-known/pki-validation/(?:\\ Ballot169)?',
            'RewriteCond %{REQUEST_URI} ^/\\.well-known/cpanel-dcv/[0-9a-zA-Z_-]+$',
            'RewriteCond %{REQUEST_URI} ^/\\.well-known/pki-validation/[A-F0-9]{32}\\.txt(?:\\ QAPortal\\ DCV)?$',
            'RewriteCond %{REQUEST_URI} ^/\\.well-known/pki-validation/[A-F0-9]{32}\\.txt(?:\\ Sectigo\\ DCV)?$',
            'RewriteCond %{HTTP_HOST} !^mock.server.tld$',
            'RewriteCond %{HTTP_HOST} ^cpanel\\.',
            'RewriteCond %{HTTP:Upgrade} !websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} !^mock.server.tld$',
            'RewriteCond %{HTTP_HOST} ^webmail\\.',
            'RewriteCond %{HTTP:Upgrade} !websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} !^mock.server.tld$',
            'RewriteCond %{HTTP_HOST} ^whm\\.',
            'RewriteCond %{HTTP:Upgrade} !websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} !^mock.server.tld$',
            'RewriteCond %{HTTP_HOST} ^webdisk\\.',
            'RewriteCond %{HTTP_HOST} !^mock.server.tld$',
            'RewriteCond %{HTTP_HOST} ^cpcalendars\\.',
            'RewriteCond %{HTTP_HOST} !^mock.server.tld$',
            'RewriteCond %{HTTP_HOST} ^cpcontacts\\.',
            'RewriteCond %{HTTP_HOST} !^mock.server.tld$',
            'RewriteCond %{HTTP_HOST} ^autodiscover\\.',
            'RewriteCond %{HTTP_HOST} !^mock.server.tld$',
            'RewriteCond %{HTTP_HOST} ^autoconfig\\.',
            'RewriteCond %{HTTP_HOST} ^cpanel\\.',
            'RewriteCond %{HTTP:Upgrade} websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} ^webmail\\.',
            'RewriteCond %{HTTP:Upgrade} websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} ^whm\\.',
            'RewriteCond %{HTTP:Upgrade} websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} !^mock.server.tld$',
            'RewriteCond %{HTTP_HOST} ^cpanel\\.',
            'RewriteCond %{HTTP:Upgrade} !websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} !^mock.server.tld$',
            'RewriteCond %{HTTP_HOST} ^webmail\\.',
            'RewriteCond %{HTTP:Upgrade} !websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} !^mock.server.tld$',
            'RewriteCond %{HTTP_HOST} ^whm\\.',
            'RewriteCond %{HTTP:Upgrade} !websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} !^mock.server.tld$',
            'RewriteCond %{HTTP_HOST} ^webdisk\\.',
            'RewriteCond %{HTTP_HOST} !^mock.server.tld$',
            'RewriteCond %{HTTP_HOST} ^cpcontacts\\.',
            'RewriteCond %{HTTP_HOST} !^mock.server.tld$',
            'RewriteCond %{HTTP_HOST} ^cpcalendars\\.',
            'RewriteCond %{HTTP_HOST} !^mock.server.tld$',
            'RewriteCond %{HTTP_HOST} ^autodiscover\\.',
            'RewriteCond %{HTTP_HOST} !^mock.server.tld$',
            'RewriteCond %{HTTP_HOST} ^autoconfig\\.',
            'RewriteCond %{HTTP_HOST} ^cpanel\\.',
            'RewriteCond %{HTTP:Upgrade} websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} ^webmail\\.',
            'RewriteCond %{HTTP:Upgrade} websocket   [nocase]',
            'RewriteCond %{HTTP_HOST} ^whm\\.',
            'RewriteCond %{HTTP:Upgrade} websocket   [nocase]'
        ],
        'expected line found with proxy subdomains enabled'
    ) or note explain $lines_ar;

    $input_hr->{proxysubdomains} = 0;

    ( $status, $output ) = Cpanel::Template::process_template( "apache2_4", $input_hr, { 'skip_local' => 1 } );

    ok( $status, 'Template processed ok!' );

    $lines_ar = _get_rewritecond_lines($output);
    cmp_bag(
        $lines_ar,
        [
            'RewriteCond %{REQUEST_URI} ^/\\.well-known/pki-validation/[A-F0-9]{32}\\.txt(?:\\ QAPortal\\ DCV)?$',
            'RewriteCond %{REQUEST_URI} ^/\\.well-known/pki-validation/(?:\\ Ballot169)?',
            'RewriteCond %{REQUEST_URI} ^/\\.well-known/pki-validation/[A-F0-9]{32}\\.txt(?:\\ Sectigo\\ DCV)?$',
            'RewriteCond %{REQUEST_URI} ^/\\.well-known/cpanel-dcv/[0-9a-zA-Z_-]+$',
            'RewriteCond %{HTTP_HOST} !^(?:autoconfig|autodiscover|cpanel|cpcalendars|cpcontacts|webdisk|webmail|whm)\\.'
        ],
        'Without proxysubdomains enabled less are in the config file upon generation'
    ) or note explain $lines_ar;

    return;
}

# Need to remove [OR] as well for now as the order can change
sub _get_rewritecond_lines {
    my ($output_ref) = @_;

    return [ map { s/^\s*//g; s/\s*$//g; s/\s*\[OR\]$//g; $_ } grep { index( $_, 'RewriteCond' ) > -1 } split( "\n", $$output_ref ) ];    ## no critic qw(ControlStructures::ProhibitMutatingListFunctions) - I'm doing this on purpose
}

1;

__DATA__
{
  "serve_server_status": 0,
  "_use_target_version": "2_4",
  "serverroot": "/etc/apache2",
  "service": "apache",
  "sections": {
    "mainifmodulealiasmodule": "main.<ifmodule  alias_module>",
    "ifmodulemodlogconfigc": "<ifmodule  mod_log_config.c>",
    "maindirectoryusrlocalapachehtdocs": "main.<directory  \"/usr/local/apache/htdocs\">",
    "mainifmoduleitkc": "main.<ifmodule  itk.c>",
    "ifmoduleitkc": "<ifmodule  itk.c>",
    "maindirectory": "main.<directory  \"/\">",
    "mainifmoduleworkerc": "main.<ifmodule  worker.c>",
    "maindirectoryusrlocalapachecgibin": "main.<directory  \"/usr/local/apache/cgi-bin\">",
    "directory": "<directory  \"/\">",
    "ifmodulelogiomodule": "<ifmodule  logio_module>",
    "ifmodulealiasmodule": "<ifmodule  alias_module>",
    "mainfilesht": "main.<files  \".ht*\">",
    "mainifmodulemodlogconfigc": "main.<ifmodule  mod_log_config.c>",
    "ifmodulepreforkc": "<ifmodule  prefork.c>",
    "ifmodulelogconfigmodule": "<ifmodule  log_config_module>",
    "mainifmodulemimemodule": "main.<ifmodule  mime_module>",
    "mainifmodulelogconfigmodule": "main.<ifmodule  log_config_module>",
    "mainifmodulelogconfigmoduleifmodulelogiomodule": "main.<ifmodule  log_config_module>.<ifmodule  logio_module>",
    "filesht": "<files  \".ht*\">",
    "ifmoduleworkerc": "<ifmodule  worker.c>",
    "directoryusrlocalapachecgibin": "<directory  \"/usr/local/apache/cgi-bin\">",
    "mainifmodulepreforkc": "main.<ifmodule  prefork.c>",
    "ifmodulemimemodule": "<ifmodule  mime_module>",
    "directoryusrlocalapachehtdocs": "<directory  \"/usr/local/apache/htdocs\">"
  },
  "_initialized": 1,
  "serve_server_info": 0,
  "_target_conf_file": "/etc/apache2/conf/httpd.conf",
  "so_dir": "modules",
  "allow_server_info_status_from": "",
  "configured": {
    "main_port_ssl": "443",
    "ip_listen": [
      "0.0.0.0",
      "[::]"
    ],
    "main_port": "80",
    "ip_listen_ssl": [
      "0.0.0.0",
      "[::]"
    ]
  },
  "defaultvhost": {
    "userdirprotect": "-1"
  },
  "servername": "mock.server.tld",
  "main_ip": "1.1.1.1",
  "main": {
    "alias": {
      "directive": "alias",
      "items": [
        {
          "path": "/usr/local/bandmin/htdocs/",
          "url": "/bandwidth"
        },
        {
          "path": "/usr/local/cpanel/img-sys/",
          "url": "/img-sys"
        },
        {
          "path": "/usr/local/cpanel/java-sys/",
          "url": "/java-sys"
        },
        {
          "url": "/mailman/archives",
          "path": "/usr/local/cpanel/3rdparty/mailman/archives/public/"
        },
        {
          "url": "/pipermail",
          "path": "/usr/local/cpanel/3rdparty/mailman/archives/public/"
        },
        {
          "url": "/sys_cpanel",
          "path": "/usr/local/cpanel/sys_cpanel/"
        }
      ]
    },
    "documentroot": {
      "directive": "documentroot",
      "item": {
        "documentroot": "/usr/local/apache/htdocs"
      }
    },
    "ifmoduleitkc": {
      "mutex": {
        "directive": "mutex",
        "items": [
          {
            "mechanism": "default",
            "name": "mpm-accept",
            "directive": "Mutex"
          }
        ]
      }
    },
    "ifmodulemodlogconfigc": {
      "logformat": {
        "directive": "logformat",
        "items": [
          {
            "logformat": "\"%h %l %u %t \\\"%r\\\" %>s %b \\\"%{Referer}i\\\" \\\"%{User-Agent}i\\\"\" combined"
          },
          {
            "logformat": "\"%h %l %u %t \\\"%r\\\" %>s %b\" common"
          },
          {
            "logformat": "\"%{Referer}i -> %U\" referer"
          },
          {
            "logformat": "\"%{User-agent}i\" agent"
          }
        ]
      },
      "customlog": {
        "items": [
          {
            "format": "common",
            "target": "logs/access_log"
          }
        ],
        "directive": "customlog"
      }
    },
    "mainifmodulemodlogconfigc": {
      "directive": "<ifmodule",
      "item": {
        "ifmodule": "mod_log_config.c"
      }
    },
    "errorlog": {
      "item": {
        "errorlog": "\"logs/error_log\""
      },
      "directive": "errorlog"
    },
    "directory": {
      "allowoverride": {
        "directive": "allowoverride",
        "item": {
          "allowoverride": "All"
        }
      },
      "options": {
        "item": {
          "options": "All"
        },
        "directive": "options"
      }
    },
    "group": {
      "directive": "group",
      "item": {
        "group": "nobody"
      }
    },
    "scriptalias": {
      "items": [
        {
          "url": "/cgi-sys",
          "path": "/usr/local/cpanel/cgi-sys/"
        },
        {
          "url": "/mailman",
          "path": "/usr/local/cpanel/3rdparty/mailman/cgi-bin/"
        }
      ],
      "directive": "scriptalias"
    },
    "mainifmodulelogconfigmoduleifmodulelogiomodule": {
      "directive": "<ifmodule",
      "item": {
        "ifmodule": "logio_module"
      }
    },
    "filesht": {
      "require": {
        "item": {
          "require": "all denied"
        },
        "directive": "require"
      }
    },
    "rewriteengine": {
      "item": {
        "rewriteengine": "on"
      },
      "directive": "rewriteengine"
    },
    "serversignature": {
      "item": {
        "serversignature": "On"
      },
      "directive": "serversignature"
    },
    "addtype": {
      "directive": "addtype",
      "items": [
        {
          "extension": ".shtml",
          "mime": "text/html"
        }
      ]
    },
    "serveradmin": {
      "item": {
        "serveradmin": "jason@cpanel.net"
      },
      "directive": "serveradmin"
    },
    "mainifmodulelogconfigmodule": {
      "directive": "<ifmodule",
      "item": {
        "ifmodule": "log_config_module"
      }
    },
    "mainifmodulemimemodule": {
      "directive": "<ifmodule",
      "item": {
        "ifmodule": "mime_module"
      }
    },
    "ifmodulelogconfigmodule": {
      "customlog": {
        "items": [
          {
            "format": "common",
            "target": "\"logs/access_log\""
          }
        ],
        "directive": "customlog"
      },
      "logformat": {
        "items": [
          {
            "logformat": "\"%h %l %u %t \\\"%r\\\" %>s %b \\\"%{Referer}i\\\" \\\"%{User-Agent}i\\\"\" combined"
          },
          {
            "logformat": "\"%h %l %u %t \\\"%r\\\" %>s %b\" common"
          }
        ],
        "directive": "logformat"
      },
      "ifmodulelogiomodule": {
        "logformat": {
          "items": [
            {
              "logformat": "\"%h %l %u %t \\\"%r\\\" %>s %b \\\"%{Referer}i\\\" \\\"%{User-Agent}i\\\" %I %O\" combinedio"
            }
          ],
          "directive": "logformat"
        }
      }
    },
    "extendedstatus": {
      "item": {
        "extendedstatus": "On"
      },
      "directive": "extendedstatus"
    },
    "scriptaliasmatch": {
      "directive": "scriptaliasmatch",
      "items": [
        {
          "path": "/usr/local/cpanel/cgi-sys/redirect.cgi",
          "regex": "^/?controlpanel/?$"
        },
        {
          "path": "/usr/local/cpanel/cgi-sys/redirect.cgi",
          "regex": "^/?cpanel/?$"
        },
        {
          "regex": "^/?kpanel/?$",
          "path": "/usr/local/cpanel/cgi-sys/redirect.cgi"
        },
        {
          "regex": "^/?securecontrolpanel/?$",
          "path": "/usr/local/cpanel/cgi-sys/sredirect.cgi"
        },
        {
          "path": "/usr/local/cpanel/cgi-sys/sredirect.cgi",
          "regex": "^/?securecpanel/?$"
        },
        {
          "path": "/usr/local/cpanel/cgi-sys/swhmredirect.cgi",
          "regex": "^/?securewhm/?$"
        },
        {
          "regex": "^/?whm/?$",
          "path": "/usr/local/cpanel/cgi-sys/whmredirect.cgi"
        },
        {
          "regex": "^/Autodiscover/Autodiscover.xml",
          "path": "/usr/local/cpanel/cgi-sys/autodiscover.cgi"
        },
        {
          "regex": "^/autodiscover/autodiscover.xml",
          "path": "/usr/local/cpanel/cgi-sys/autodiscover.cgi"
        },
        {
          "path": "/usr/local/cpanel/cgi-sys/wredirect.cgi",
          "regex": "^/?webmail(/.*|/?)$"
        }
      ]
    },
    "loadmodule": {
      "directive": "loadmodule",
      "items": [
        {
          "filename": "modules/mod_bwlimited.so",
          "module": "bwlimited_module"
        }
      ]
    },
    "directoryusrlocalapachecgibin": {
      "options": {
        "item": {
          "options": "All"
        },
        "directive": "options"
      },
      "require": {
        "item": {
          "require": "all granted"
        },
        "directive": "require"
      },
      "allowoverride": {
        "directive": "allowoverride",
        "item": {
          "allowoverride": "None"
        }
      }
    },
    "directoryindex": {
      "item": {
        "directoryindex": "index.html.var index.htm index.html index.shtml index.xhtml index.wml index.perl index.pl index.plx index.ppl index.cgi index.jsp index.js index.jp index.php4 index.php3 index.php index.phtml default.htm default.html home.htm index.php5 Default.html Default.htm home.html"
      },
      "directive": "directoryindex"
    },
    "lockfile": {
      "directive": "lockfile",
      "item": {
        "lockfile": "/usr/local/apache/logs/accept.lock"
      }
    },
    "servername": {
      "directive": "servername",
      "item": {
        "servername": "mock.server.tld"
      }
    },
    "maindirectory": {
      "item": {
        "directory": "/"
      },
      "directive": "<directory"
    },
    "mainifmoduleworkerc": {
      "directive": "<ifmodule",
      "item": {
        "ifmodule": "worker.c"
      }
    },
    "mainifmodulealiasmodule": {
      "directive": "<ifmodule",
      "item": {
        "ifmodule": "alias_module"
      }
    },
    "listen": {
      "directive": "listen",
      "item": {
        "listen": "80"
      }
    },
    "maindirectoryusrlocalapachehtdocs": {
      "directive": "<directory",
      "item": {
        "directory": "/usr/local/apache/htdocs"
      }
    },
    "pidfile": {
      "item": {
        "pidfile": "logs/httpd.pid"
      },
      "directive": "pidfile"
    },
    "mainifmoduleitkc": {
      "directive": "<ifmodule",
      "item": {
        "ifmodule": "itk.c"
      }
    },
    "ifmodulepreforkc": {
      "mutex": {
        "items": [
          {
            "directive": "Mutex",
            "name": "mpm-accept",
            "mechanism": "default"
          }
        ],
        "directive": "mutex"
      }
    },
    "user": {
      "directive": "user",
      "item": {
        "user": "nobody"
      }
    },
    "mainfilesht": {
      "directive": "<files",
      "item": {
        "files": "\".ht*\""
      }
    },
    "ifmodulealiasmodule": {
      "scriptalias": {
        "directive": "scriptalias",
        "items": [
          {
            "url": "/cgi-bin/",
            "path": "\"/usr/local/apache/cgi-bin/\""
          }
        ]
      }
    },
    "timeout": {
      "item": {
        "timeout": "300"
      },
      "directive": "timeout"
    },
    "loglevel": {
      "directive": "loglevel",
      "item": {
        "loglevel": "warn"
      }
    },
    "maindirectoryusrlocalapachecgibin": {
      "item": {
        "directory": "/usr/local/apache/cgi-bin"
      },
      "directive": "<directory"
    },
    "include": {
      "items": [
        {
          "include": "\"/usr/local/apache/conf/php.conf\""
        },
        {
          "include": "\"/usr/local/apache/conf/includes/errordocument.conf\""
        },
        {
          "include": "\"/usr/local/apache/conf/includes/account_suspensions.conf\""
        },
        {
          "include": "\"/usr/local/apache/conf/modsec2.conf\""
        }
      ],
      "directive": "include"
    },
    "optimize_htaccess": {
      "item": {}
    },
    "ifmodulemimemodule": {
      "addtype": {
        "items": [
          {
            "extension": ".Z",
            "mime": "application/x-compress"
          },
          {
            "mime": "application/x-gzip",
            "extension": ".gz .tgz"
          }
        ],
        "directive": "addtype"
      },
      "typesconfig": {
        "directive": "typesconfig",
        "item": {
          "typesconfig": "conf/mime.types"
        }
      }
    },
    "directoryusrlocalapachehtdocs": {
      "require": {
        "directive": "require",
        "item": {
          "require": "all granted"
        }
      },
      "options": {
        "directive": "options",
        "item": {
          "options": "All"
        }
      },
      "allowoverride": {
        "directive": "allowoverride",
        "item": {
          "allowoverride": "None"
        }
      }
    },
    "serverroot": {
      "item": {
        "serverroot": "/usr/local/apache"
      },
      "directive": "serverroot"
    },
    "mainifmodulepreforkc": {
      "item": {
        "ifmodule": "prefork.c"
      },
      "directive": "<ifmodule"
    },
    "ifmoduleworkerc": {
      "mutex": {
        "items": [
          {
            "mechanism": "default",
            "name": "mpm-accept",
            "directive": "Mutex"
          }
        ],
        "directive": "mutex"
      }
    }
  },
  "supported": {
    "sni": 1,
    "mod_authz_groupfile": 1,
    "mod_autoindex": 1,
    "mod_authn_core": 1,
    "core": 1,
    "mod_authz_host": 1,
    "mod_socache_dbm": 1,
    "mod_mpm_worker": 1,
    "http_core": 1,
    "mod_proxy_wstunnel": 1,
    "stapling": 1,
    "mod_slotmem_shm": 1,
    "mod_suphp": 1,
    "mod_authz_core": 1,
    "mod_userdir": 1,
    "mod_rewrite": 1,
    "mod_security2": 1,
    "mod_alias": 1,
    "mod_cgid": 1,
    "http_core_module": 1,
    "mod_unique_id": 1,
    "mod_proxy_http": 1,
    "phpsuexec": 0,
    "mod_mime": 1,
    "mod_access_compat": 1,
    "mod_auth_basic": 1,
    "mod_authn_file": 1,
    "mod_suexec": 1,
    "mod_bwlimited": 1,
    "mod_status": 1,
    "mod_so": 1,
    "mod_authz_user": 1,
    "mod_ssl": 1,
    "mod_dir": 1,
    "mod_actions": 1,
    "mod_unixd": 1,
    "mod_logio": 1,
    "core_module": 1,
    "mod_filter": 1,
    "mod_log_config": 1,
    "mod_negotiation": 1,
    "mod_include": 1,
    "so_module": 1,
    "mod_socache_shmcb": 1,
    "mod_proxy": 1,
    "mod_setenvif": 1
  },
  "default_apache_ssl_port": "443",
  "paths": {
    "bin_suexec": "/usr/sbin/suexec",
    "dir_docroot": "/var/www/html",
    "bin_httpd": "/usr/sbin/httpd",
    "file_error_log": "/etc/apache2/logs/error_log",
    "dir_logs": "/etc/apache2/logs",
    "dir_modules": "/etc/apache2/modules",
    "file_access_log": "/etc/apache2/logs/access_log",
    "dir_run": "/run/apache2",
    "dir_conf_userdata": "/etc/apache2/conf.d/userdata",
    "file_conf": "/etc/apache2/conf/httpd.conf",
    "dir_base": "/etc/apache2",
    "dir_domlogs": "/etc/apache2/logs/domlogs",
    "file_conf_mime_types": "/etc/mime.types",
    "dir_conf": "/etc/apache2/conf.d",
    "file_conf_srm_conf": "/etc/apache2/conf.d/srm.conf",
    "file_conf_php_conf": "/etc/apache2/conf.d/php.conf",
    "bin_apachectl": "/usr/sbin/apachectl",
    "dir_conf_includes": "/etc/apache2/conf.d/includes"
  },
  "proxysubdomains": "1",
  "template_file": "/usr/local/repos/ea-apache2-config/SOURCES/ea4_main.default",
  "main_ipv6": null,
  "sharedips": [
    "1.1.1.1:80"
  ],
  "_follow": "",
  "serveradmin": "jason@cpanel.net",
  "scriptalias": 1,
  "enable_piped_logs": 0,
  "ssl_vhosts": [
    {
      "ip": "1.1.1.1",
      "sslcertificatefile": "/var/cpanel/ssl/apache_tls/mock.server.tld/combined",
      "ips": [
        {
          "ip": "1.1.1.1",
          "port": "443"
        }
      ],
      "hascgi": 1,
      "ifmoduleincludemodule": {
        "directoryvarwwwhtml": {
          "ssilegacyexprparser": [
            {
              "value": " On"
            }
          ]
        }
      },
      "ifmodulelogconfigmodule": {
        "ifmodulelogiomodule": {
          "customlog": [
            {
              "format": "\"%{%s}t %I .\\n%{%s}t %O .\"",
              "target": "/usr/local/apache/domlogs/mock.server.tld-bytes_log"
            }
          ]
        }
      },
      "rewritecond": [
        {
          "rewritecond": "%{HTTP_HOST} =autodiscover.mock.server.tld"
        },
        {
          "rewritecond": "%{HTTP_HOST} =cpanel.mock.server.tld"
        },
        {
          "rewritecond": "%{HTTP_HOST} =webdisk.mock.server.tld"
        },
        {
          "rewritecond": "%{HTTP_HOST} =webmail.mock.server.tld"
        }
      ],
      "enable_sni_for_mail": "1",
      "rewriteengine": "On",
      "phpopenbasedirprotect": 1,
      "serveradmin": "webmaster@mock.server.tld",
      "proxypass": [
        {
          "proxypass": "\"/___proxy_subdomain_cpanel\" \"http://127.0.0.1:2082\" max=1 retry=0"
        },
        {
          "proxypass": "\"/___proxy_subdomain_webdisk\" \"http://127.0.0.1:2077\" max=1 retry=0"
        },
        {
          "proxypass": "\"/___proxy_subdomain_webmail\" \"http://127.0.0.1:2095\" max=1 retry=0"
        }
      ],
      "secruleengineoff": null,
      "group": "nobody",
      "homedir": "/",
      "php_fpm": 0,
      "ifmoduleheadersmodule": {
        "requestheader": [
          {
            "requestheader": "set X-HTTPS 1"
          }
        ]
      },
      "jailed": 0,
      "ifmodulesslmodule": {
        "sslengine": "on",
        "directoryvarwwwhtmlcgibin": {
          "ssloptions": "+StdEnvVars"
        },
        "sslcertificatekeyfile": "/var/cpanel/ssl/installed/keys/bc5bf_a04ed_906c7da475a9d804519d6dfdd0af0796.key",
        "setenvif": [
          {
            "env_variables": "nokeepalive ssl-unclean-shutdown",
            "regex": "\".*MSIE.*\"",
            "attribute": "User-Agent"
          }
        ],
        "sslcertificatefile": "/var/cpanel/ssl/installed/certs/jason64_dev_cpanel_net_bc5bf_a04ed_1510795690_50db4dcade1d44b80a758c6707d4ffb3.crt"
      },
      "documentroot": "/var/www/html",
      "owner": "root",
      "default_vhost_sort_priority": 1,
      "ssl": "1",
      "userdirprotect": "-1",
      "log_servername": "mock.server.tld",
      "optimize_htaccess": null,
      "sort_priority": 3,
      "ipv6": null,
      "user": "nobody",
      "port": "443",
      "usecanonicalname": "Off",
      "customlog": [
        {
          "target": "/usr/local/apache/domlogs/mock.server.tld-ssl_log",
          "format": "combined"
        }
      ],
      "ifmodulealiasmodule": {
        "scriptalias": [
          {
            "path": "/var/www/html/cgi-bin/",
            "url": "/cgi-bin/"
          }
        ]
      },
      "ifmoduleuserdirmodule": {
        "ifmodulempmitkc": {
          "ifmoduleruidmodule": {}
        }
      },
      "proxy_subdomains": {
        "cpanel": [
          "mock.server.tld"
        ],
        "webmail": [
          "mock.server.tld"
        ],
        "autodiscover": [
          "mock.server.tld"
        ],
        "webdisk": [
          "mock.server.tld"
        ]
      },
      "serveralias_array": [
        "www.mock.server.tld"
      ],
      "rewriterule": [
        {
          "pattern": "^",
          "substitution": "http://127.0.0.1/cgi-sys/autodiscover.cgi",
          "qualifier": "[P]"
        },
        {
          "qualifier": "[PT]",
          "pattern": "^/(.*)",
          "substitution": "/___proxy_subdomain_cpanel/$1"
        },
        {
          "qualifier": "[PT]",
          "pattern": "^/(.*)",
          "substitution": "/___proxy_subdomain_webdisk/$1"
        },
        {
          "qualifier": "[PT]",
          "pattern": "^/(.*)",
          "substitution": "/___proxy_subdomain_webmail/$1"
        }
      ],
      "servername": "mock.server.tld",
      "serveralias": "www.mock.server.tld"
    },
    {
      "log_servername": "lawfulevil.tld",
      "optimize_htaccess": null,
      "phpopenbasedirprotect": null,
      "serveradmin": "webmaster@lawfulevil.tld",
      "ip": "1.1.1.1",
      "sslcertificatefile": "/var/cpanel/ssl/apache_tls/lawfulevil.tld/combined",
      "ips": [
        {
          "ip": "1.1.1.1",
          "port": "443"
        }
      ],
      "default_vhost_sort_priority": 0,
      "hascgi": 1,
      "userdirprotect": "",
      "ssl": 1,
      "jailed": 0,
      "proxy_subdomains": {
        "webdisk": [
          "lawfulevil.tld",
          "neutralevil.tld"
        ],
        "webmail": [
          "lawfulevil.tld",
          "neutralevil.tld"
        ],
        "autodiscover": [
          "lawfulevil.tld",
          "neutralevil.tld"
        ],
        "cpanel": [
          "lawfulevil.tld",
          "neutralevil.tld"
        ]
      },
      "serveralias_array": [
        "mail.lawfulevil.tld www.lawfulevil.tld neutralevil.tld www.neutralevil.tld www.mail.lawfulevil.tld webdisk.lawfulevil.tld webmail.lawfulevil.tld autodiscover.lawfulevil.tld cpanel.lawfulevil.tld"
      ],
      "servername": "lawfulevil.tld",
      "documentroot": "/home/lawfulevil/public_html",
      "owner": "root",
      "serveralias": "mail.lawfulevil.tld www.lawfulevil.tld neutralevil.tld www.neutralevil.tld www.mail.lawfulevil.tld webdisk.lawfulevil.tld webmail.lawfulevil.tld autodiscover.lawfulevil.tld cpanel.lawfulevil.tld",
      "secruleengineoff": null,
      "sort_priority": 3,
      "group": "lawfulevil",
      "homedir": "/home/lawfulevil",
      "ipv6": null,
      "user": "lawfulevil",
      "port": "443",
      "usecanonicalname": "Off",
      "php_fpm": 0
    },
    {
      "serveradmin": "webmaster@whm.tld",
      "phpopenbasedirprotect": null,
      "log_servername": "whm.tld",
      "optimize_htaccess": null,
      "userdirprotect": "",
      "ssl": 1,
      "ip": "1.1.1.1",
      "sslcertificatefile": "/var/cpanel/ssl/apache_tls/whm.tld/combined",
      "ips": [
        {
          "ip": "1.1.1.1",
          "port": "443"
        }
      ],
      "default_vhost_sort_priority": 0,
      "hascgi": 1,
      "servername": "whm.tld",
      "documentroot": "/home/whm/public_html",
      "serveralias": "mail.whm.tld www.whm.tld cpanel.whm.tld webdisk.whm.tld whm.whm.tld autodiscover.whm.tld webmail.whm.tld",
      "owner": "whm",
      "jailed": 0,
      "proxy_subdomains": {
        "cpanel": [
          "whm.tld"
        ],
        "webdisk": [
          "whm.tld"
        ],
        "whm": [
          "whm.tld"
        ],
        "autodiscover": [
          "whm.tld"
        ],
        "webmail": [
          "whm.tld"
        ]
      },
      "serveralias_array": [
        "mail.whm.tld www.whm.tld cpanel.whm.tld webdisk.whm.tld whm.whm.tld autodiscover.whm.tld webmail.whm.tld"
      ],
      "user": "whm",
      "ipv6": null,
      "usecanonicalname": "Off",
      "port": "443",
      "php_fpm": 0,
      "secruleengineoff": null,
      "sort_priority": 3,
      "group": "whm",
      "homedir": "/home/whm"
    }
  ],
  "phpopenbasedirprotect_enabled": 0,
  "vhosts": [
    {
      "ip": "1.1.1.1",
      "default_vhost_sort_priority": 1,
      "ips": [
        {
          "ip": "1.1.1.1",
          "port": "80"
        }
      ],
      "hascgi": 1,
      "log_servername": "whm.tld",
      "optimize_htaccess": null,
      "scriptalias": [
        {
          "path": "/home/whm/public_html/cgi-bin",
          "url": "/cgi-bin/"
        }
      ],
      "serveradmin": "webmaster@whm.tld",
      "phpopenbasedirprotect": 1,
      "sort_priority": 3,
      "group": "whm",
      "homedir": "/home/whm",
      "user": "whm",
      "port": "80",
      "usecanonicalname": "Off",
      "customlog": [
        {
          "target": "/etc/apache2/logs/domlogs/whm.tld",
          "format": "combined"
        },
        {
          "format": "\"%{%s}t %I .\\n%{%s}t %O .\"",
          "target": "/etc/apache2/logs/domlogs/whm.tld-bytes_log"
        }
      ],
      "php_fpm": 0,
      "jailed": 0,
      "serveralias_array": [
        "mail.whm.tld www.whm.tld"
      ],
      "servername": "whm.tld",
      "documentroot": "/home/whm/public_html",
      "serveralias": "mail.whm.tld www.whm.tld",
      "owner": "whm"
    },
    {
      "serveradmin": "webmaster@lawfulevil.tld",
      "phpopenbasedirprotect": 1,
      "scriptalias": [
        {
          "path": "/home/lawfulevil/public_html/cgi-bin",
          "url": "/cgi-bin/"
        },
        {
          "path": "/home/lawfulevil/public_html/cgi-bin/",
          "url": "/cgi-bin/"
        }
      ],
      "ifmodulelogconfigmodule": {
        "ifmodulelogiomodule": {
          "customlog": [
            {
              "target": "/usr/local/apache/domlogs/lawfulevil.tld-bytes_log",
              "format": "\"%{%s}t %I .\\n%{%s}t %O .\""
            }
          ]
        }
      },
      "ifmoduleincludemodule": {
        "directoryhomelawfulevilpublichtml": {
          "ssilegacyexprparser": [
            {
              "value": " On"
            }
          ]
        }
      },
      "hascgi": 1,
      "ifmodulemodincludec": {
        "directoryhomelawfulevilpublichtml": {
          "ssilegacyexprparser": [
            {
              "value": " On"
            }
          ]
        }
      },
      "ips": [
        {
          "ip": "1.1.1.1",
          "port": "80"
        }
      ],
      "ip": "1.1.1.1",
      "owner": "root",
      "documentroot": "/home/lawfulevil/public_html",
      "ifmoduleconcurrentphpc": {},
      "jailed": 0,
      "ifmodulemodsuphpc": {
        "group": "lawfulevil"
      },
      "akey": "some data",
      "php_fpm": 0,
      "group": "lawfulevil",
      "homedir": "/home/lawfulevil",
      "optimize_htaccess": null,
      "log_servername": "lawfulevil.tld",
      "userdirprotect": "-1",
      "default_vhost_sort_priority": 0,
      "serveralias": "mail.lawfulevil.tld www.lawfulevil.tld www.mail.lawfulevil.tld",
      "servername": "lawfulevil.tld",
      "serveralias_array": [
        "mail.lawfulevil.tld www.lawfulevil.tld www.mail.lawfulevil.tld"
      ],
      "ifmoduleuserdirmodule": {
        "ifmodulempmitkc": {
          "ifmoduleruidmodule": {}
        }
      },
      "ifmodulealiasmodule": {
        "scriptalias": [
          {
            "url": "/cgi-bin/",
            "path": "/home/lawfulevil/public_html/cgi-bin/"
          }
        ]
      },
      "usecanonicalname": "Off",
      "port": "80",
      "customlog": [
        {
          "target": "/usr/local/apache/domlogs/lawfulevil.tld",
          "format": "combined"
        },
        {
          "format": "\"%{%s}t %I .\\n%{%s}t %O .\"",
          "target": "/usr/local/apache/domlogs/lawfulevil.tld-bytes_log"
        }
      ],
      "user": "lawfulevil",
      "sort_priority": 3
    },
    {
      "group": "lawfulevil",
      "sort_priority": 1,
      "homedir": "/home/lawfulevil",
      "php_fpm": 0,
      "ifmodulealiasmodule": {
        "scriptalias": [
          {
            "path": "/home/lawfulevil/public_html/cgi-bin/",
            "url": "/cgi-bin/"
          }
        ]
      },
      "customlog": [
        {
          "format": "combined",
          "target": "/usr/local/apache/domlogs/mail.lawfulevil.tld"
        }
      ],
      "port": "80",
      "usecanonicalname": "Off",
      "user": "lawfulevil",
      "serveralias_array": [
        "www.mail.lawfulevil.tld"
      ],
      "jailed": 0,
      "ifmoduleuserdirmodule": {
        "ifmodulempmitkc": {
          "ifmoduleruidmodule": {}
        }
      },
      "owner": "root",
      "serveralias": "www.mail.lawfulevil.tld",
      "documentroot": "/home/lawfulevil/public_html",
      "servername": "mail.lawfulevil.tld",
      "hascgi": 1,
      "default_vhost_sort_priority": 0,
      "ips": [
        {
          "ip": "1.1.1.1",
          "port": "80"
        }
      ],
      "ip": "1.1.1.1",
      "userdirprotect": "-1",
      "ifmoduleincludemodule": {
        "directoryhomelawfulevilpublichtml": {
          "ssilegacyexprparser": [
            {
              "value": " On"
            }
          ]
        }
      },
      "optimize_htaccess": null,
      "ifmodulelogconfigmodule": {
        "ifmodulelogiomodule": {
          "customlog": [
            {
              "target": "/usr/local/apache/domlogs/mail.lawfulevil.tld-bytes_log",
              "format": "\"%{%s}t %I .\\n%{%s}t %O .\""
            }
          ]
        }
      },
      "log_servername": "mail.lawfulevil.tld",
      "serveradmin": "webmaster@mail.lawfulevil.tld",
      "phpopenbasedirprotect": 1
    }
  ],
  "serve_apache_manual": 1,
  "namevirtualhosts": [
    "1.1.1.1:443",
    "1.1.1.1:80",
    "127.0.0.1:80"
  ],
  "options_support": {
    "DYNAMIC_MODULE_LIMIT": "256",
    "v4-mapped": 0,
    "APR_HAS_MMAP": 1,
    "APR_HAS_OTHER_CHILD": 1,
    "build": "Sep 19 2017 20:05:47",
    "split_version": [
      "2",
      "4",
      "27"
    ],
    "APR_HAS_SENDFILE": 1,
    "AP_HAVE_RELIABLE_PIPED_LOGS": 1,
    "APR_USE_SYSVSEM_SERIALIZE": 1,
    "APR_USE_PTHREAD_SERIALIZE": 1,
    "AP_TYPES_CONFIG_FILE": "conf/mime.types",
    "SERVER_CONFIG_FILE": "conf/httpd.conf",
    "DEFAULT_PIDLOG": "/var/run/apache2/httpd.pid",
    "version": "2.4.27",
    "APR_HAVE_IPV6": 1,
    "SINGLE_LISTEN_UNSERIALIZED_ACCEPT": 1,
    "DEFAULT_SCOREBOARD": "logs/apache_runtime_status",
    "SUEXEC_BIN": "/usr/sbin/suexec",
    "mpm": "worker",
    "DEFAULT_ERRORLOG": "logs/error_log",
    "HTTPD_ROOT": "/etc/apache2"
  },
  "default_apache_port": "80",
  "autodiscover_proxy_subdomains": "1",
  "custom": {},
  "logstyle": "combined",
  "userdirprotect_enabled": "1",
  "jailapache": "0",
  "compiled_support": {
    "core.c": 1,
    "mod_so.c": 1,
    "http_core.c": 1
  },
  "shared_objects": {
    "mod_authn_core.so": 1,
    "mod_socache_dbm.so": 1,
    "mod_negotiation.so": 1,
    "mod_suexec.so": 1,
    "mod_alias.so": 1,
    "mod_auth_basic.so": 1,
    "mod_mpm_worker.so": 1,
    "mod_security2.so": 1,
    "mod_userdir.so": 1,
    "mod_proxy_http.so": 1,
    "mod_authn_file.so": 1,
    "mod_rewrite.so": 1,
    "mod_unique_id.so": 1,
    "mod_proxy.so": 1,
    "mod_unixd.so": 1,
    "mod_logio.so": 1,
    "mod_access_compat.so": 1,
    "mod_authz_user.so": 1,
    "mod_dir.so": 1,
    "mod_authz_host.so": 1,
    "mod_slotmem_shm.so": 1,
    "mod_socache_shmcb.so": 1,
    "mod_suphp.so": 1,
    "mod_autoindex.so": 1,
    "mod_log_config.so": 1,
    "mod_authz_core.so": 1,
    "mod_actions.so": 1,
    "mod_proxy_wstunnel.so": 1,
    "mod_bwlimited.so": 1,
    "mod_ssl.so": 1,
    "mod_include.so": 1,
    "mod_authz_groupfile.so": 1,
    "mod_status.so": 1,
    "mod_mime.so": 1,
    "mod_filter.so": 1,
    "mod_cgid.so": 1,
    "mod_setenvif.so": 1
  },
  "includes": {
    "ssl_vhost": "",
    "cpanel": "",
    "vhost": "",
    "user": ""
  }
}

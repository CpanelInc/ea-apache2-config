#-------------------------------------------------------------------------------------
#
# Start Configuration
#
#-------------------------------------------------------------------------------------

# name of the file in the SPECS directory
SPEC := httpd.spec

# name of the file in the SRPMS directory
SRPM := httpd24-1.0-0.el6.src.rpm

# name of the configuration file in /etc/mock (excluding .cfg)
CFG := ea4-httpd24-epel-6-x86_64

# inspect build environment (on by default)
# NOTE: This is useful if you don't want mock to clean up after itself
CLEAN_ROOT ?= 1

#-------------------------------------------------------------------------------------
#
# End Configuration
#
#-------------------------------------------------------------------------------------

#-------------------
# Variables
#-------------------

whoami := $(shell whoami)

ifeq (root, $(whoami))
	MOCK := /usr/bin/mock
else
	MOCK := /usr/sbin/mock
endif

CACHE := /var/cache/mock/$(CFG)/root_cache/cache.tar.gz
MOCK_CFG := /etc/mock/$(CFG).cfg

MOCK_BASE_ARGS := --unpriv
MOCK_SRPM_ARGS := $(MOCK_BASE_ARGS)
MOCK_RPM_ARGS := $(MOCK_BASE_ARGS)

ifeq ($(CLEAN_ROOT),0)
	MOCK_RPM_ARGS := $(MOCK_RPM_ARGS) --no-cleanup-after
endif

.PHONY: all pristine clean

#-----------------------
# Primary make targets
#-----------------------

# (Re)Build SRPMs and RPMs
all: $(MOCK_CFG) clean make-build

# Same as 'all', but also rebuilds all cached data
pristine: $(MOCK_CFG) clean make-pristine make-build

# Remove per-build temp directory
clean:
	rm -rf RPMS SRPMS
	$(MOCK) -v -r $(CFG) --clean

#-----------------------
# Helper make targets
#-----------------------

# Remove the root filesystem tarball used for the build environment
make-pristine:
	$(MOCK) -v -r $(CFG) --scrub=all
	rm -rf SRPMS RPMS

# Build SRPM
make-srpm-build: $(CACHE)
	$(MOCK) -v -r $(CFG) $(MOCK_SRPM_ARGS) --resultdir SRPMS --buildsrpm --spec SPECS/$(SPEC) --sources SOURCES

# Build RPMs
make-rpm-build: $(CACHE)
	$(MOCK) -v -r $(CFG) $(MOCK_RPM_ARGS) --resultdir RPMS SRPMS/$(SRPM)

# Build both SRPM and RPMs
make-build: make-srpm-build make-rpm-build

# Create/update the root cache containing chroot env used by mock
$(CACHE):
	$(MOCK) -v -r $(CFG) --init --update

# Ensure the mock configuration is installed
$(MOCK_CFG):
	sudo cp $(CFG).cfg $@


# You should configure etckeeper.conf for your distribution before
# installing etckeeper.
CONFFILE=etckeeper.conf
include $(CONFFILE)

DESTDIR?=
prefix=/usr/local
bindir=${prefix}/bin
libexecdir=${prefix}/libexec
etcdir=/usr/local/etc
mandir=${prefix}/man
vardir=/var
systemddir=/lib/systemd/system
bashcompletiondir=${prefix}/share/bash-completion/completions
zshcompletiondir=${prefix}/share/zsh/site-functions
CP=cp -R
INSTALL=install 
INSTALL_EXE=${INSTALL}
INSTALL_DATA=${INSTALL} -m 0644
PYTHON=python
FAKEROOT := $(shell command -v fakeroot 2> /dev/null)
TESTDIR := $(shell mktemp -u -d)
ifeq ($(LOWLEVEL_PACKAGE_MANAGER),pkgng)
CMAN=etckeeper.8.gz
endif

build: etckeeper.spec etckeeper.version
	-$(PYTHON) ./etckeeper-bzr/__init__.py build || echo "** bzr support not built"
	-$(PYTHON) ./etckeeper-dnf/etckeeper.py build || echo "** DNF support not built"

install: etckeeper.version $(CMAN)
	mkdir -p $(DESTDIR)$(etcdir)/etckeeper/ $(DESTDIR)$(vardir)/cache/etckeeper/
	$(CP) *.d $(DESTDIR)$(etcdir)/etckeeper/
ifeq ($(LOWLEVEL_PACKAGE_MANAGER),pkgng)
	mkdir -p $(DESTDIR)$(libexecdir)/etckeeper/
	$(INSTALL_EXE) daily $(DESTDIR)$(libexecdir)/etckeeper/daily
else
	$(INSTALL_EXE) daily $(DESTDIR)$(etcdir)/etckeeper/daily
endif
	$(INSTALL_DATA) $(CONFFILE) $(DESTDIR)$(etcdir)/etckeeper/etckeeper.conf
	mkdir -p $(DESTDIR)$(bindir)
	$(INSTALL_EXE) etckeeper $(DESTDIR)$(bindir)/etckeeper
	mkdir -p $(DESTDIR)$(mandir)/man8
	$(INSTALL_DATA) etckeeper.8.gz $(DESTDIR)$(mandir)/man8/etckeeper.8.gz
	mkdir -p $(DESTDIR)$(bashcompletiondir)
	$(INSTALL_DATA) bash_completion $(DESTDIR)$(bashcompletiondir)/etckeeper
	mkdir -p $(DESTDIR)$(zshcompletiondir)
	$(INSTALL_DATA) zsh_completion $(DESTDIR)$(zshcompletiondir)/_etckeeper
ifneq ($(LOWLEVEL_PACKAGE_MANAGER),pkgng)
	mkdir -p $(DESTDIR)$(systemddir)
	$(INSTALL_DATA) systemd/etckeeper.service $(DESTDIR)$(systemddir)/etckeeper.service
	$(INSTALL_DATA) systemd/etckeeper.timer $(DESTDIR)$(systemddir)/etckeeper.timer
endif
ifeq ($(HIGHLEVEL_PACKAGE_MANAGER),apt)
	mkdir -p $(DESTDIR)$(etcdir)/apt/apt.conf.d
	$(INSTALL_DATA) apt.conf $(DESTDIR)$(etcdir)/apt/apt.conf.d/05etckeeper
	mkdir -p $(DESTDIR)$(etcdir)/cruft/filters-unex
	$(INSTALL_DATA) cruft_filter $(DESTDIR)$(etcdir)/cruft/filters-unex/etckeeper
endif
ifeq ($(LOWLEVEL_PACKAGE_MANAGER),pacman)
	mkdir -p $(DESTDIR)$(prefix)/share/libalpm/hooks
	$(INSTALL_DATA) ./pacman-pre-install.hook $(DESTDIR)$(prefix)/share/libalpm/hooks/05-etckeeper-pre-install.hook
	$(INSTALL_DATA) ./pacman-post-install.hook $(DESTDIR)$(prefix)/share/libalpm/hooks/zz-etckeeper-post-install.hook
endif
ifeq ($(LOWLEVEL_PACKAGE_MANAGER),pacman-g2)
	mkdir -p $(DESTDIR)$(etcdir)/pacman-g2/hooks
	$(INSTALL_DATA) pacman-g2.hook $(DESTDIR)$(etcdir)/pacman-g2/hooks/etckeeper
endif
ifeq ($(HIGHLEVEL_PACKAGE_MANAGER),yum)
	mkdir -p $(DESTDIR)$(prefix)/lib/yum-plugins
	$(INSTALL_DATA) yum-etckeeper.py $(DESTDIR)$(prefix)/lib/yum-plugins/etckeeper.py
	mkdir -p $(DESTDIR)$(etcdir)/yum/pluginconf.d
	$(INSTALL_DATA) yum-etckeeper.conf $(DESTDIR)$(etcdir)/yum/pluginconf.d/etckeeper.conf
endif
ifeq ($(HIGHLEVEL_PACKAGE_MANAGER),dnf)
	-$(PYTHON) ./etckeeper-dnf/etckeeper.py install --root=$(DESTDIR) ${PYTHON_INSTALL_OPTS} || echo "** DNF support not installed"
endif
ifeq ($(HIGHLEVEL_PACKAGE_MANAGER),zypper)
	mkdir -p $(DESTDIR)$(prefix)/lib/zypp/plugins/commit
	$(INSTALL) zypper-etckeeper.py $(DESTDIR)$(prefix)/lib/zypp/plugins/commit/zypper-etckeeper.py
endif
ifeq ($(LOWLEVEL_PACKAGE_MANAGER),pkgng)
	$(INSTALL_EXE) pkgng/pkg-delete-wrapper $(DESTDIR)$(libexecdir)/etckeeper/pkg-delete-wrapper
	$(INSTALL_EXE) pkgng/pkg-register-wrapper $(DESTDIR)$(libexecdir)/etckeeper/pkg-register-wrapper
	$(INSTALL_EXE) pkgng/etckeeper-dirs $(DESTDIR)$(libexecdir)/etckeeper/etckeeper-dirs
	mkdir -p $(DESTDIR)$(etcdir)/periodic/daily
	$(INSTALL_EXE) pkgng/etckeeper_autocommit $(DESTDIR)$(etcdir)/periodic/daily/etckeeper_autocommit
ifeq ($(DESTDIR),)
	# Typically DESTDIR is used for packaging system.
	# For those cases, this adjustment should be in post-install/deinstall scripts.
	pkgng/adjust_make_conf install
endif
endif
	-$(PYTHON) ./etckeeper-bzr/__init__.py install --root=$(DESTDIR) ${PYTHON_INSTALL_OPTS} || echo "** bzr support not installed"
	echo "** installation successful"

clean: etckeeper.spec etckeeper.version
	rm -rf build etckeeper.8.gz

test:
	mkdir $(TESTDIR)
ifdef FAKEROOT
	testdir=$(TESTDIR) fakeroot ./test-etckeeper
else
	testdir=$(TESTDIR) ./test-etckeeper
endif
	rm -rf $(TESTDIR)

etckeeper.spec:
	sed -i~ "s/Version:.*/Version: $$(perl -e '$$_=<>;m/\((.*?)(-.*)?\)/;print $$1;'<CHANGELOG)/" etckeeper.spec
	rm -f etckeeper.spec~

etckeeper.version:
	sed -i~ "s/Version:.*/Version: $$(perl -e '$$_=<>;m/\((.*?)(-.*)?\)/;print $$1;' <CHANGELOG)\"/" etckeeper
	rm -f etckeeper~

ifeq ($(LOWLEVEL_PACKAGE_MANAGER),pkgng)
etckeeper.8.gz: etckeeper.8
	gzip --keep --force $^
endif

.PHONY: etckeeper.spec etckeeper.version

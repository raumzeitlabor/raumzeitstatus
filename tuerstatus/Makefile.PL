#!/usr/bin/env perl
# vim:ts=4:sw=4:expandtab
use strict;
use warnings;
use inc::Module::Install;

name     'RaumZeitTuerstatus';
all_from 'lib/RaumZeitLabor/Hausbus/Tuerstatus.pm';
author   q{Simon Elsbrock <simon@iodev.org>};
license  'gpl';

requires 'AnyEvent';
requires 'AnyEvent::HTTP';
requires 'AnyEvent::HTTP::Stream';
requires 'JSON::XS';
requires 'RRDTool::OO';
requires 'YAML::Syck';

install_script 'scripts/tuerstatusd';

postamble <<'END_OF_MAKEFILE';
install:: extra_install
pure_install:: extra_install
install_vendor:: extra_install

extra_install:
	install -d $(DESTDIR)/etc/rsyslog.d/ $(DESTDIR)/etc/
	install -m 755 tuerstatusd.rsyslog $(DESTDIR)/etc/rsyslog.d/tuerstatusd.conf
	install -m 640 tuerstatusd.yml.ex $(DESTDIR)/etc/tuerstatusd.yml
	install -D -m 644 status-tuer.rrd $(DESTDIR)/var/cache/rrd/status-tuer.rrd
	install -D -m 644 debian/raumzeittuerstatus.service $(DESTDIR)/lib/systemd/system/raumzeittuerstatus.service
END_OF_MAKEFILE

WriteAll;

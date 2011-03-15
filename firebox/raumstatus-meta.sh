#!/bin/sh

# Informationen sammeln
/root/leases.pl

/root/npm-status.pl

# TODO: Informationen aufbereiten

# Auf status.raumzeitlabor.de laden
/root/dav-upload.pl
/root/status-graph.sh

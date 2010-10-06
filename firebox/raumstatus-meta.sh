#!/bin/sh

# Informationen sammeln
/root/tuerstatus.pl
/root/leases.pl

# TODO: Informationen aufbereiten

# Auf status.raumzeitlabor.de laden
/root/dav-upload.pl
/root/status-graph.sh

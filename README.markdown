# RaumZeitStatus – Statusanzeiger für das RaumZeitLabor

Die Scripts in firebox/ holen vom Etherrape den Raumstatus und mithilfe der
Leases-Datei des DHCP-Servers und eines Broadcast-Pings die im Netz
befindlichen Geräte, protokollieren beides jeweils in einer RRD-Datei und
laden anschließend einen generierten Graphen sowie full.json und simple.txt
via WebDAV auf status.raumzeitlabor.de.

## Adressen

 * [status.raumzeitlabor.de/](http://status.raumzeitlabor.de/)
 * [api/simple (einfache Textrepräsentation)](http://status.raumzeitlabor.de/api/simple)
 * [api/full.json (JSON-Datei mit Details)](http://status.raumzeitlabor.de/api/full.json)

## Setup

1. RRD-Datenbanken erstellen:

    rrdtool create status-tuer.rrd -s 60 DS:tuer:GAUGE:120:U:U RRA:LAST:0:1:10080
    rrdtool create status-geraete.rrd -s 60 DS:geraete:GAUGE:120:U:U RRA:LAST:0:1:10080

2. MySQL-Datenbank einrichten:

    CREATE TABLE leases (
      `ip` varchar(39) NOT NULL,
      `mac` varchar(17) NOT NULL,
      `ipv4_reachable` tinyint(1) NOT NULL,
      `ipv6_reachable` tinyint(1) NOT NULL,
      `hostname` text,
       PRIMARY KEY  (`ip`)
     ) ENGINE=MyISAM DEFAULT CHARSET=latin1

3. davconfig.pm und sqlconfig.pm befüllen
4. Etherrape anschließen
5. raumstatus-meta.sh als Cronjob einrichten
6. WebDAV einrichten:

    <Location /update/>
       Dav On
       AuthType Digest
       AuthName "update"
       AuthDigestDomain /update/ http://status.raumzeitlabor.de/update/
       AuthDigestProvider file
       AuthUserFile /data/www/status.raumzeitlabor.de/conf/digest-update
       Require valid-user
    </Location>

7. status-unreachable.pl als Cronjob einrichten

## Lizenz

> Copyright © 2010 Felix Arndt
> Copyright © 2010 Michael Stapelberg
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of
> this software and associated documentation files (the "Software"), to deal in
> the Software without restriction, including without limitation the rights to
> use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
> of the Software, and to permit persons to whom the Software is furnished to do
> so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

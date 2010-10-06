#!/bin/sh
/usr/bin/rrdtool graph /var/www/status-1day.png -s 'now-1day' -w 800 -h 400 -E \
	DEF:tuer=status-tuer.rrd:tuer:LAST  \
	DEF:geraete=status-geraete.rrd:geraete:LAST \
	CDEF:g=geraete,geraete,FLOOR,-,0.5,-,geraete,geraete,FLOOR,-,0.5,-,ABS,+,geraete,CEIL,geraete,FLOOR,IF \
	AREA:tuer#e2ffe2 \
	LINE2:tuer#77ff77:"Türstatus" \
	LINE2:g#ff7777:"Geräte im Netz" \
	GPRINT:g:AVERAGE:\(%.1lf\ Geräte\ im\ Schnitt\)

/usr/bin/rrdtool graph /var/www/status-1week.png \
	-t 'Status des RaumZeitLabors über die letzte Woche' \
	-s 'now-1week' -w 800 -h 400 -E \
	DEF:tuer=status-tuer.rrd:tuer:LAST  \
	DEF:geraete=status-geraete.rrd:geraete:LAST \
	CDEF:g=geraete,geraete,FLOOR,-,0.5,-,geraete,geraete,FLOOR,-,0.5,-,ABS,+,geraete,CEIL,geraete,FLOOR,IF \
	"CDEF:p=tuer,100,*" \
	AREA:tuer#e2ffe2 \
	LINE2:tuer#77ff77:"Türstatus" \
	GPRINT:p:AVERAGE:\(zu\ %.1lf%%\ offen\ im\ Schnitt\) \
	GPRINT:tuer:LAST:\(momentan\\:\ \ %.1lf\)\\j \
	LINE2:g#ff7777:"Geräte im Netz" \
	GPRINT:g:AVERAGE:\(%.1lf\ Geräte\ im\ Schnitt\) \
	GPRINT:g:LAST:\(momentan\\:\ %2.1lf\)

<?php
/* von http://php.net/manual/de/function.header.php */
header("Cache-Control: no-cache, must-revalidate");
header("Expires: Sat, 26 Jul 1997 05:00:00 GMT");
?>
<html>
<head>
<title>RaumZeitLabor: Status</title>
<meta http-equiv="content-type" content="text/html; charset=utf-8" />
<link rel="alternate" type="application/rss+xml" title="RSS"
 href="http://identi.ca/api/statuses/user_timeline/191025.rss">
<style type="text/css">
body {
	font-family: Verdana, sans-serif;
}
</style>
</head>
<body>
<h1>Aktueller Status</h1>
<div style="text-align: center">
<?php
$roomStatus = file_get_contents('http://scytale.name/files/tmp/rzlstatus.txt');
switch ($roomStatus) {
case '1':
	$bild = 'images/green.png';
	$status = 'Raum ist offen';
	break;
case '0':
	$bild = 'images/red.png';
	$status = 'Raum ist zu';
	break;
default:
	$bild = 'images/orange.png';
	$status = 'Status kann nicht ermittelt werden';
	break;
}

echo '<img src="' . $bild . '" alt="Raumstatus"><br>';
echo $status;
?>
</div>

<h1>Infos</h1>

<p>
Der aktuelle Status kann über http://www.raumzeitlabor.de (oben rechts), über
die Webapp oder im IRC via <code>!!raum</code> abgerufen werden.
</p>

<p>
Der Raumstatus wird automatisch durch einen Schalter in der Tür gesetzt.
</p>

<h2>IRC</h2>

<p>
In den Räumen #oqlt und #raumzeitlabor (hackint) kann der Status via
<code>!!raum</code> abgefragt werden.
</p>

<h2>Web 2.0</h2>

<p>
Der Status wird auch auf <a
href="http://identi.ca/RaumZeitStatus">Identi.ca</a> und auf <a
href="http://twitter.com/raumzeitstatus">Twitter</a> veröffentlicht.
</p>

<h2>RSS</h2>
<p>
Identi.ca hat einen öffentlichen RSS-Feed über welchen der Status auch
ohne Identi.ca Account abgefragt werden kann. Den Feed gibts unter 
<a href="http://identi.ca/api/statuses/user_timeline/191025.rss">http://identi.ca/api/statuses/user_timeline/191025.rss</a>
</p>

</body>
</html>

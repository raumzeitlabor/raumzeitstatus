<?php
/* von http://php.net/manual/de/function.header.php */
header("Cache-Control: no-cache, must-revalidate");
header("Expires: Sat, 26 Jul 1997 05:00:00 GMT");
?>
<!DOCTYPE html>
<html>
<head>
<title>RaumZeitLabor: Status</title>
<meta charset="utf-8" />
<link rel="alternate" type="application/rss+xml" title="RSS"
 href="http://identi.ca/api/statuses/user_timeline/191025.rss">
<style type="text/css">
body {
	margin: 0px;
	padding-left: 1em;
	font-family: Trebuchet MS, Verdana, sans-serif;
	width: 900px;
}

h1 {
        margin-top: 0.25em;
        font-size: 48px;
}

img {
	border: 0;
}
</style>
</head>
<body>
<div style="float: right; margin-right: 1em; text-align: center">
<a href="http://twitter.com/RaumZeitStatus">
<img src="twitter.png" width="43" height="43" alt="Follow on twitter">
</a>
<br>
<a href="http://identi.ca/raumzeitstatus">
<img src="identica.png" width="50" height="50" alt="RaumZeitStatus on identi.ca">
</a>
<br>
<a href="http://github.com/raumzeitlabor/raumzeitstatus">
<img src="github.png" width="100" height="45" alt="Sourcecode">
</a>
</div>
<h1>Status des RaumZeitLabors</h1>

<?php
$roomStatus = trim(file_get_contents('http://status.raumzeitlabor.de/api/simple'));
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

echo '<img src="' . $bild . '" alt="Raumstatus" style="float: left; padding-right: 1em">';
?>
<h2>Aktueller Status</h2>
<?php echo $status; ?>

<br style="clear: both">

<h2>Geräte im Netz</h2>
<img src="status-1week.png">

<h2>Temperatur</h2>
<img src="https://api.pachube.com/v2/feeds/42055/datastreams/Temperatur_Raum_Tafel.png?width=881&height=340&colour=F15A24&duration=24hours&detailed_grid=true&show_axis_labels=true&timezone=">

<h2>Stromverbrauch</h2>
<img src="http://api.pachube.com/v2/feeds/42055/datastreams/Strom_Leistung.png?width=866&height=300&colour=F15A24&duration=24hours&detailed_grid=true&show_axis_labels=true&timezone=">


</body>
</html>

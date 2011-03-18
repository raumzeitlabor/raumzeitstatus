<?php
/* von http://php.net/manual/de/function.header.php */
header("Cache-Control: no-cache, must-revalidate");
header("Expires: Sat, 26 Jul 1997 05:00:00 GMT");
?>
<html>
<head>
	<title>RaumZeitLabor Raumstatus</title>
	<meta name="viewport" content="width=device-width; initial-scale=1.0; maximum-scale=1.0; user-scalable=0;" />
	<link rel="apple-touch-icon" href="rzl.png" />
</head>
<body style="min-height: 420px; text-align: center" onload="setTimeout(function() { window.scrollTo(0, 1) }, 100);">
<span style="text-align: center">
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

echo '<img width="128px" src="' . $bild . '"  style="display: block; margin-left: auto; margin-right: auto;" alt="Offen" />';
echo $status;
?>

</span>
</body>
</html>

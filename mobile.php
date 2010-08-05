<html>
<head>
	<title>RaumZeitLabor Raumstatus</title>
	<meta name="viewport" content="width=device-width; initial-scale=1.0; maximum-scale=1.0; user-scalable=0;" />
	<link rel="apple-touch-icon" href="rzl.png" />
</head>
<body style="min-height: 420px;" onload="setTimeout(function() { window.scrollTo(0, 1) }, 100);">
<span style="text-align: center;">
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

echo '<img width="128px" src="' . $bild . '"  style="display: block; margin-left: auto; margin-right: auto;" alt="Offen" />';
echo $status;
?>

</span>
</body>
</html>

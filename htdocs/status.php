<?php
/* von http://php.net/manual/de/function.header.php */
header("Cache-Control: no-cache, must-revalidate");
header("Expires: Sat, 26 Jul 1997 05:00:00 GMT");

$roomStatus = trim(file_get_contents('/data/www/status.raumzeitlabor.de/htdocs/update/simple.txt'));
switch ($roomStatus) {
case '1':
	$bild = 'images/green.png';
	break;
case '0':
	$bild = 'images/red.png';
	break;
default:
	$bild = 'images/orange.png';
	break;
}

header("Content-Type: image/png");
readfile($bild);
?>

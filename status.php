<?php

header('Content-type: image/png');

$roomStatus = (int)file_get_contents('room');

$bild = null;

switch ($roomStatus) {
case 1:
	$bild = "images/green.png";
	break;
case 2:
	$bild = "images/orange.png";
	break;
case 0:
	$bild = "images/red.png";
	break;
}

if ($bild !== null)
	@readfile($bild);

?>

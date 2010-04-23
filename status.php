<?php
header("content-type: image/png");


$handler = fopen("room" , "r");
	$roomStatus = fgets($handler, 2);
	switch($roomStatus){
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
	
	$im = @readfile($bild);
	return $im;

?>

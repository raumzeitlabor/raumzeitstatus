<?php
$set = (int)$_GET['set'];
$handler = fopen("room" , "w+");
switch($set){
	case 0:
		fwrite($handler, "0");
		break;
		
	case 1:
		fwrite($handler, "1");
		break;
		
	case 2:
		fwrite($handler, "2");
		break;
	
	default:
		echo "Fehler. Status konnte nicht gesetzt werden.";
}
fclose($handler);
?>

<?php
if (isset($_GET['set'])) {
	$set = (int)$_GET['set'];
	switch ($set) {
		case 0:
		case 1:
		case 2:
			file_put_contents('room', $set);
			break;
		default:
			echo "Fehler. Status konnte nicht gesetzt werden.";
	}
}
?>

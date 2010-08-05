<html>
<head>
	<title>RaumZeitLabor Raumstatus</title>
	<meta name="viewport" content="width=device-width; initial-scale=1.0; maximum-scale=1.0; user-scalable=0;" />
	<link rel="apple-touch-icon" href="rzl.png" />
</head>
<body style="min-height: 420px;" onload="setTimeout(function() { window.scrollTo(0, 1) }, 100);">
	<?php $roomStatus = (int)file_get_contents('http://scytale.name/files/tmp/rzlstatus.txt');
	switch($roomStatus){
		case 1:
			echo '<span style="text-align: center;"><img width="128px" style="display: block; margin-left: auto; margin-right: auto;" src="status.php/offen.png" alt="Offen" />'; break;
		case 0:
			echo '<span style="text-align: center;"><img width="128px" style="display: block; margin-left: auto; margin-right: auto;" src="status.php/zu.png" alt="Geschlossen" />'; break;
	}?>

	</form></span>
</body>
</html>

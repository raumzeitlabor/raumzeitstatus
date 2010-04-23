<?php

$set = $_POST['set'];

if(isset($set)){
	$handler = fopen("room" , "w+");
	switch($set){
	case 1:
		fwrite($handler, "1");
		break;
		
	case 0:
		fwrite($handler, "0");
		break;
	
	}
	fclose($handler);
}
?>

<html>
<head>
	<title>RaumZeitLabor Raumstatus</title>
	<meta name="viewport" content="width=device-width; initial-scale=1.0; maximum-scale=1.0; user-scalable=0;" />
	<link rel="apple-touch-icon" href="rzl.png">
</head>
<body style="min-height: 420px;" onload="setTimeout(function() { window.scrollTo(0, 1) }, 100);">
	<span style="text-align: center;"><img width="150px" style="display: block; margin-left: auto; margin-right: auto;" src="status.php">
	<form action="mobile.php" method="post">
		<?php
			$handler = fopen("room" , "r");
				$roomStatus = fgets($handler, 2);
 				switch($roomStatus){
					case 1:
			        	$info = '<input style="font-size: 20px;" type="submit" value="Raum schlie&szlig;en"><input type="hidden" value="0" name="set">';
						break;
			        
			        case 0:
			        	$info = '<input style="font-size: 20px;" type="submit" value="Raum &ouml;ffnen"><input type="hidden" value="1" name="set">';
						break;
				}
				echo $info;
		?>
	</form></span>
</body>
</html>
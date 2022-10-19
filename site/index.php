<?php
	function resolve_mac($ip){
		for ($x = 0;$x < 3;$x++){
			$arp = array_map(
				fn($value) => explode(",", $value),
				explode(
					"\n",
					shell_exec(
						"tail -n+2 < /proc/net/arp |
						grep 'lnxr0$' |
						awk '{print $1\",\"$4}'"
					)
				)
			);

			$bool found = false;
			foreach ($arp as $line){
				if ($ip !== $line[0])
					continue;
				$found = true;
				$mac = $line[1];
				if ($mac !== "00:00:00:00:00:00")
					return $mac;
				break;
			}

			if (!$found)
				return "unknown";
			sleep(1);
		}
		return "unknown";
	}

	$ip = $_SERVER['REMOTE_ADDR'];
	echo "Your ip is ".$ip." and your mac is ".resolve_mac($ip);
?>

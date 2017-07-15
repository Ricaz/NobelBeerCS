#!/bin/php -q
<?php
error_reporting(E_ALL);

/* Allow the script to hang around waiting for connections. */
set_time_limit(0);

define("SERVER_ADDR", "0.0.0.0");
define("SERVER_PORT_WS", 5001);
define("SERVER_PORT_MOD", 1337);
define("DB_HOSTNAME", "localhost");
define("DB_USERNAME", "");
define("DB_PASSWORD", "");
define("DB_DATABASE", "ol_cs");
define("DEFAULT_THEME", "default");

require_once "libs/websockets.php";


class WSServer extends WebSocketServer
{
	protected function process($client, $message) {
	}
  
	protected function connected($client) {
		echo "Starting mod server\n";
		$modserver = new ModServer(SERVER_ADDR, SERVER_PORT_MOD, $this, $client);
		$modserver->start();
	}
	
	protected function closed($client) {
		echo "Connection closed to WS client!\n";
	}
}

class ModServer
{
	protected $socket;
	protected $db;
	protected $clients;
	protected $ws_server;
	protected $ws_client;
	protected $theme = DEFAULT_THEME;
	
	public function __construct($addr, $port, $ws_server, $ws_client)
	{
		if (($this->socket = socket_create(AF_INET, SOCK_STREAM, SOL_TCP)) === false) {
			die("socket_create() failed: reason: " . socket_strerror(socket_last_error()) . "\n");
		}

		if (!socket_set_option($this->socket, SOL_SOCKET, SO_REUSEADDR, 1)) {
			die("socket_set_option() failed: reason: ". socket_strerror(socket_last_error()) ."\n");
		}
		
		if (!socket_set_option($this->socket, SOL_SOCKET, SO_LINGER, array ('l_linger' => 0, 'l_onoff' => 0))) {
			die("socket_set_option() failed: reason: ". socket_strerror(socket_last_error()) ."\n");
		}

		if (socket_bind($this->socket, $addr, $port) === false) {
			debug_print_backtrace();
			die("socket_bind() failed: reason: " . socket_strerror(socket_last_error($this->socket)) . "\n");
		}

		if (socket_listen($this->socket, 5) === false) {
			die("socket_listen() failed: reason: " . socket_strerror(socket_last_error($this->socket)) . "\n");
		}
		
		$this->clients = [$this->socket];
		
		$this->db = mysqli_connect(DB_HOSTNAME, DB_USERNAME, DB_PASSWORD);
		mysqli_select_db($this->db, DB_DATABASE);
		
		$this->ws_server = $ws_server;
		$this->ws_client = $ws_client;

		echo "Started server on ". $addr.":". $port ."\n";	
	}
	
	protected function ws_send($msg)
	{
		//echo "Sending msg to ws client: ${msg}\n";
		$val = $this->ws_server->send($this->ws_client, $msg) !== false;
		
//		var_dump(socket_last_error($this->ws_client->socket));
		
		return $val;
	}
	
	public function start()
	{
		if (!$this->ws_send("ready"))
			return;
		
		while (true)
		{
			// create a copy, so $clients doesn't get modified by socket_select()
			$read = $this->clients;
			$write = [];
			$except = [];
			if (socket_select($read, $write, $except, 1) < 1
			  && !in_array($this->socket, $read)) 
			{
				if (!$this->ws_send("stats|€@!|" . $this->get_stats()))
					continue;
			}
			
			$client = socket_accept($this->socket);
			
			echo "Mod client connected\n";
			
			if ($client === false) {
				echo "socket_accept() failed: reason: " . socket_strerror(socket_last_error($this->socket)) . "\n";
			}

			$data = socket_read($client, 64);
			socket_close($client);
			$data = str_replace("\r", "", $data);
			$data = str_replace("\n", "", $data);

			$name = null;
			@list($cmd, $name, $name2) = explode("|€@!|", $data);

			echo "RAW DATA=<$data>, CMD=<$cmd>, NAME=<$name>\n";

			switch ($cmd)
			{
				case "tk":
					$this->generate_teamkill_image($name, $name2);
					break;
				case "knife":
					$this->generate_knifed_image($name, $name2);
					break;
				case "kniferound":
					$this->generate_kniferound_image($name);
					break;
				case "round":
					#					$this->stop_sound();
					break;
				case "unpause":
					$this->stop_sound();
					break;
				case "theme":
					if (file_exists(dirname(__FILE__) . "/sounds/" . $name)) 
						$this->theme = $name;
					break;
			}

			$this->play_sound($cmd);
				
			if (!$this->ws_send("stats|€@!|" . $this->get_stats()))
				break;
			
			// Forward to WS server
			if (!$this->ws_send($data))
				break;
		}
		
		echo "Connection to WS client closed\n";
		mysqli_close($this->db);
		socket_close($this->socket);
		//$wsserver->disconnect($wsClient);
	}

	protected function play_sound($dir)
	{
		$full_dir = dirname(__FILE__) . "/sounds/" . $this->theme . "/" . $dir;
		if (!file_exists($full_dir))
			return;

		$files = glob($full_dir ."/*");
		if (count($files) === 0) {
			$full_dir = dirname(__FILE__) . "/sounds/" . DEFAULT_THEME . "/" . $dir;
			$files = glob($full_dir ."/*");
		}

		if (count($files) === 0)
			return;

		$file = $files[ mt_rand(0, count($files)-1) ];
		echo "Playing sound: " . $dir . "/" . basename($file) . "\n";
		exec("mplayer -really-quiet -noconsolecontrols -nolirc $file < /dev/null > /dev/null &");
	}
	
	protected function stop_sound()
	{
		exec("killall mplayer 2> /dev/null");
	}
	
	protected function get_stats()
	{
		$var = '';
		$var .= "<h1 class=\"text-center\">NOBEL ØL CS STATS</h1>";
		$var .= "<hr />";
		$var .= "<table class=\"table-responsive table-bordered\">";
		$var .= "<tr>";
		$var .= "<th>Nickname</th>";
		$var .= "<th>Kills</th>";
		$var .= "<th>Team kills</th>";
		$var .= "<th>Knifed</th>";
		$var .= "<th>Got knifed</th>";
		$var .= "<th>Rounds</th>";
		$var .= "<th>Sips</th>";
		$var .= "</tr>";
		
		$query = mysqli_query($this->db, "SELECT * FROM stats ORDER BY sips DESC");
		while ($row = mysqli_fetch_assoc($query)) 
		{
			$name = $row["name"];
			$name = str_replace("Ã†", "Æ", $name);
			$name = str_replace("Ã˜", "Ø", $name);
			$name = str_replace("Ã…", "Å", $name);
			$name = str_replace("Ã¦", "æ", $name);
			$name = str_replace("Ã¸", "ø", $name);
			$name = str_replace("Ã¥", "å", $name);
			$var .= "<tr data-steamid=\"". $row["steamid"] ."\">\n";
			$var .= "<td>". $name ."</td>\n";
			$var .= "<td class='text-center'>". $row["kills"] ."</td>\n";
			$var .= "<td class='text-center'>". $row["tks"] ."</td>\n";
			$var .= "<td class='text-center'>". $row["knifed"] ."</td>\n";
			$var .= "<td class='text-center'>". $row["got_knifed"] ."</td>\n";
			$var .= "<td class='text-center'>". $row["rounds"] ."</td>\n";
			$var .= "<td><b>". $row["sips"] ."</b></td>\n";
			$var .= "</tr>";
		}
		
		$var .= "<tr style='height: 100%;'></tr>";
		$var .= "</table>";
		
		return $var;
	}

	protected function generate_kniferound_image($killer)
	{
		$image = imagecreatefrompng("images/kniferound.png");
		$bbox = imagettfbbox(50, 0, "./FreeMono.ttf", "U retarded, $killer ??!?");
		$width = $bbox[4] - $bbox[0];
		$height = $bbox[1] - $bbox[5];

		$centerx = (1920 - $width) / 2;
		imagettftext($image, 50, 0, $centerx, $height + 50, imagecolorallocate($image, 255, 255, 255), "./FreeMono.ttf", "U retarded, $killer??!?");
		imagepng($image, "generated_images/kniferound.png");



//		$image = imagecreatefrompng("images/knife.png");
//		$bbox = imagettfbbox(50, 30, "./FreeMono.ttf", "U retarded, $killer??!?!");
//		$bbox2 = imagettfbbox(50, 30, "./FreeMono.ttf", "By $killer");
	//	var_dump($bbox);
//		imagettftext($image, 50, 30, 960 - ($bbox[2]/2) - 100, 540 - ($bbox[5]/2) - 100, imagecolorallocate($image, 255, 255, 255), "./FreeMono.ttf", "U retarded, $killer??!?!");
//		imagettftext($image, 50, 30, 960 - ($bbox2[2]/2), 540 - ($bbox2[5]/2) + 200, imagecolorallocate($image, 255, 255, 255), "./FreeMono.ttf", "By $killer");
//		imagepng($image, "generated_images/kniferound.png");
	}

	protected function generate_knifed_image($killer, $knifed)
	{
		$image = imagecreatefrompng("images/knife.png");
		$bbox = imagettfbbox(50, 30, "./FreeMono.ttf", "$knifed was knifed!");
		$bbox2 = imagettfbbox(50, 30, "./FreeMono.ttf", "By $killer");
	//	var_dump($bbox);
		imagettftext($image, 50, 30, 960 - ($bbox[2]/2) - 100, 540 - ($bbox[5]/2) - 100, imagecolorallocate($image, 255, 255, 255), "./FreeMono.ttf", "$knifed was knifed!");
		imagettftext($image, 50, 30, 960 - ($bbox2[2]/2), 540 - ($bbox2[5]/2) + 200, imagecolorallocate($image, 255, 255, 255), "./FreeMono.ttf", "By $killer");
		imagepng($image, "generated_images/knifed.png");
	}

	protected function generate_teamkill_image($killer, $victim)
	{
		$image = imagecreatefrompng("images/teamkill.png");
		$bbox = imagettfbbox(50, 0, "./FreeMono.ttf", "$victim was teamkilled by $killer!");
		$width = $bbox[4] - $bbox[0];
		$height = $bbox[1] - $bbox[5];

		$centerx = (1920 - $width) / 2;
		imagettftext($image, 50, 0, $centerx, $height + 50, imagecolorallocate($image, 255, 255, 255), "./FreeMono.ttf", "$victim was teamkilled by $killer!");
		imagepng($image, "generated_images/teamkill.png");
	}
}


echo "Waiting for client to connect....\n";
$wsserver = new WSServer(SERVER_ADDR, SERVER_PORT_WS);
$wsserver->run();

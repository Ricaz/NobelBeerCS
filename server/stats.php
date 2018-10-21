<html>
<head>
	<title>STATS</title>
	<link rel="stylesheet" type="text/css" href="//maxcdn.bootstrapcdn.com/bootstrap/3.3.4/css/bootstrap.min.css" />
	<style>
		tr:nth-child(even) {
			background-color: rgba(221, 221, 221, 0.4);
		}

		h1 {
			font-size: 64px;
	 	}
		
		table th {
			font-size: 46px;
		}
		
		table tr td {
			font-size: 32px;

		}
		
		table .borderless {
			border: 0;
		}
		
		table, div {
			width: 100%;
			height: 100%;
		}
		
		.hidden {
			display: none;
		}
		
		.visible {
			display: block;
		}
		
		body {
			margin: 0;
			overflow: hidden;
		}
		
		.video_container {
			position: fixed;
			right: 0;
			bottom: 0;
			min-width: 100%;
			min-height: 100%;
		}
	</style>
	<script type="text/javascript">
	var socket;
	var reconnecting = false;
	var delay = 0;
	var video = undefined;

	function connect()
	{
		reconnecting = false;
		try {
			var host = "ws://127.0.0.1:5001/";
			socket = new WebSocket(host);
			
			socket.onopen = function(msg)
			{
				console.log("Connected to server");
			};
			socket.onmessage = function(msg)
			{
				console.log("Received: " + msg.data);
				setTimeout(function() {
					var msg_data_split = msg.data.split("|€@!|");
					var msg_split = [msg_data_split.shift(), msg_data_split.join(" ")];
					handleCommand(msg_split[0], msg_split[1]);
				}, delay);
			};
			socket.onclose = function(msg)
			{
				reconnect();
			};
			socket.onerror = function(msg)
			{
				reconnect();
			};
			
		}
		catch(ex) { 
			console.log(ex);
			reconnect();
		}
	}
	
	function handleCommand(cmd, arg)
	{
		switch (cmd)
		{
			case "ready":
				console.log("Server ready");

				var q = getQueryParams();
				if (q.hasOwnProperty('delay')) {
					delay = (1 * q.delay);
				}

				console.log("Delay: " + delay);
				break;
			case "tk":
				//document.getElementById("image_file").src = "/generated_images/teamkill.png?" + new Date().getTime();
				//document.getElementById("stats").className = "hidden";
				//document.getElementById("image").className = "visible";
				break;
			case "kniferound":
				document.getElementById("image_file").src = "/generated_images/kniferound.png?" + new Date().getTime();
				document.getElementById("stats").className = "hidden";
				document.getElementById("image").className = "visible";
				break;
			case "knife":
				document.getElementById("image_file").src = "/generated_images/knifed.png?" + new Date().getTime();
				document.getElementById("stats").className = "hidden";
				document.getElementById("image").className = "visible";
				break;
			case "unpause":
				stopVideo();
			case "firstround":
			case "round":
				document.getElementById("image").className = "hidden";
				document.getElementById("stats").className = "visible";
				break;
			case "videofile":
				video = arg;
				break;
			case "stats":
				document.getElementById("stats").innerHTML = arg;
				break;
//			case "mapchange":
//				document.getElementById("stats").innerHTML = "<center><h1><br/><br/><br/><br/>We're on a break, stay tuned!</h1><h2>Next map: " + arg + "</h2></center>";
//				break;
		}

		if (video && cmd != "videofile" && cmd != "stats") {
			document.getElementById("video").src = "/videos/" + cmd + "/" + video;
			document.getElementById("video").currentTime = 0;
			document.getElementById("video").play();
			document.getElementById("video_container").className = "visible video_container";
			document.getElementById("video").onpause = function() {
				stopVideo();
			};
			document.getElementById("video").onended = function() {
				stopVideo();
			};
			video = undefined;
		}
	}

	function stopVideo(force = false) {
		document.getElementById("video_container").className = "hidden video_container";
		document.getElementById("video").pause();
	}
	
	function reconnect()
	{
		if (reconnecting)
			return;
		reconnecting = true;
		console.log("Reconnecting to server...");
		setTimeout("connect()", 1000);	
	}
	
	function disconnect()
	{
		if (socket != null) {
			socket.onclose = function(msg) {};
			socket.close();
		}
	}

	function getQueryParams() {
		qs = document.location.search.split('+').join(' ');

		var params = {},
			tokens,
			re = /[?&]?([^=]+)=([^&]*)/g;

		while (tokens = re.exec(qs)) {
			params[decodeURIComponent(tokens[1])] = decodeURIComponent(tokens[2]);
		}

		return params;
	}
	</script>
</head>
<body onload="connect()" onbeforeunload="disconnect()">
	<div id="video_container" class="hidden video_container">
		<video preload="auto" id="video">
		  <source id="videofile" type="video/mp4">
		</video>
	</div>
	<div class="container-fluid" >
		<div class="col-sm-12">
			<div id="stats" class="visible">
			</div>
			<div id="image" class="hidden">
				<table class="borderless fullsize">
					<tr>
						<td><img src="" id="image_file" border="0" /></td>
					</tr>
				</table>
			</div>
		</div>
	</div>
</body>

<html>
<head>
	<title>STATS</title>
	<link rel="stylesheet" type="text/css" href="//maxcdn.bootstrapcdn.com/bootstrap/3.3.4/css/bootstrap.min.css" />
	<style>
		tr:nth-child(even) {
			background-color: #DDD;
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
	</style>
	<script type="text/javascript">
	var socket;
	
	function connect()
	{
		try {
			var host = "ws://127.0.0.1:5001/";
			socket = new WebSocket(host);
			
			socket.onopen = function(msg)
			{
				console.log("Connected to server");
			};
			socket.onmessage = function(msg)
			{
//				console.log("Received: " + msg.data);
				
				var msg_data_split = msg.data.split("|€@!|");
				var msg_split = [msg_data_split.shift(), msg_data_split.join(" ")];
				handleCommand(msg_split[0], msg_split[1]);
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
				break;
			case "tk":
			console.log("handling tk event!");
				document.getElementById("image_file").src = "/generated_images/teamkill.png?" + new Date().getTime();
				document.getElementById("stats").className = "hidden";
				document.getElementById("image").className = "visible";
				break;
			case "kniferound":
				console.log("handling kniferound event!");
				document.getElementById("image_file").src = "/generated_images/kniferound.png?" + new Date().getTime();
				document.getElementById("stats").className = "hidden";
				document.getElementById("image").className = "visible";
				break;
			case "knife":
				console.log("handling knife event!");
				document.getElementById("image_file").src = "/generated_images/knifed.png?" + new Date().getTime();
				document.getElementById("stats").className = "hidden";
				document.getElementById("image").className = "visible";
				break;
			case "round":
			case "unpause":
				console.log("handling round/unpause event!");
				document.getElementById("image").className = "hidden";
				document.getElementById("stats").className = "visible";
				break;
			case "stats":
				console.log("handling stats event!");
				document.getElementById("stats").innerHTML = arg;
				break;
		}
	}
	
	function reconnect()
	{
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
	</script>
</head>
<body onload="connect()" onbeforeunload="disconnect()">
	<div class="container-fluid">
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

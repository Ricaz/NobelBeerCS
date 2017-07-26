var socket;
var host = 'ws://192.168.82.86:8080/beercs';
var protocol = 'beercs';

function connect()
{
	socket = new WebSocket(host, protocol);
	
	socket.onopen = function(msg)
	{
		console.log("Connected to server");
	};
	socket.onmessage = function(msg)
	{
		console.log("Received: " + msg.data);
		
		var msg_data_split = msg.data.split("|€@!|");
		var msg_split = [msg_data_split.shift(), msg_data_split.join(" ")];
		handleCommand(msg_split[0], msg_split[1]);
	};
	socket.onclose = function(msg)
	{
		//reconnect();
	};
	socket.onerror = function(msg)
	{
		//reconnect();
	};
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

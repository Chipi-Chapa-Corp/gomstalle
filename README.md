<div align="center">
	<h1>Gömställe</h1>
	<p>Multiplayer Hide & Seek game</p>
</div>

<div align="center">
	<h2>Running</h2>
</div>
<ul>
	<li>Clone or <a href="https://github.com/Chipi-Chapa-Corp/gomstalle/archive/refs/heads/main.zip">download</a> & unpack this project</li>
	<li>Download <a href="https://codeberg.org/godotsteam/godotsteam-server/releases/tag/v4.8">SteamGodot</a>. <i>Note: this downloads complete editor with built-in Steam support</i></li>
	<li>Run Steam and log into your Steam account</li>
	<li>Open project with downloaded editor</li>
	<li>Press Play button in top right hand corner</li>
</ul>

<div align="center">
	<h2>Local multiplayer (no Steam)</h2>
</div>
<p>Run with <code>--dev</code> to use the local ENet backend instead of Steam. Start two instances:</p>
<ul>
	<li>Host: <code>godot --dev --host</code> (or run <code>--dev</code> and press Host)</li>
	<li>Client: <code>godot --dev +connect_lobby 1</code></li>
</ul>
<p>End-to-end multiplayer is verified by <code>scripts/run_e2e_tests.sh</code>, which boots a host and a client, plays a scripted scenario, and renders side-by-side <code>host | client</code> footage to <code>gomstalle-e2e.mp4</code>.</p>

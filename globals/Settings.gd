extends Node

var network_backend: String = NetworkConfig.get_backend_name()
var local_host: String = NetworkConfig.get_local_host()
var local_port: int = NetworkConfig.get_local_port()
var local_max_clients: int = NetworkConfig.get_local_max_clients()

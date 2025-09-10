extends Node

var is_host: bool = false

var net_id: int = 0

var registry_host: String = "127.0.0.1"
var registry_port: int = 7777

# Current lobby (game server) ENet address
var lobby_host: String = "127.0.0.1"
var lobby_port: int = 9087

func get_registry_url() -> String:
    return "ws://%s:%d/ws" % [registry_host, registry_port]
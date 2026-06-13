extends Node

class_name NetworkConfig

const BACKEND_STEAM := "steam"
const BACKEND_LOCAL := "local"

const ENV_BACKEND := "GOMSTALLE_NETWORK_BACKEND"
const ENV_LOCAL_HOST := "GOMSTALLE_LOCAL_HOST"
const ENV_LOCAL_PORT := "GOMSTALLE_LOCAL_PORT"
const ENV_LOCAL_MAX_CLIENTS := "GOMSTALLE_LOCAL_MAX_CLIENTS"

const ARG_BACKEND := "network_backend"
const ARG_LOCAL_HOST := "local_host"
const ARG_LOCAL_PORT := "local_port"
const ARG_LOCAL_MAX_CLIENTS := "local_max_clients"

static func get_backend_name() -> String:
	var value := _get_env_or_arg(ENV_BACKEND, ARG_BACKEND).strip_edges().to_lower()
	if value == BACKEND_LOCAL:
		return BACKEND_LOCAL
	return BACKEND_STEAM

static func get_local_host() -> String:
	var value := _get_env_or_arg(ENV_LOCAL_HOST, ARG_LOCAL_HOST).strip_edges()
	if value.is_empty():
		return "127.0.0.1"
	return value

static func get_local_port() -> int:
	var value := _get_env_or_arg(ENV_LOCAL_PORT, ARG_LOCAL_PORT)
	var port := int(value)
	if port <= 0:
		return 24567
	return port

static func get_local_max_clients() -> int:
	var value := _get_env_or_arg(ENV_LOCAL_MAX_CLIENTS, ARG_LOCAL_MAX_CLIENTS)
	var max_clients := int(value)
	if max_clients <= 0:
		return 8
	return max_clients

static func _get_env_or_arg(env_name: String, arg_name: String) -> String:
	var env_value := OS.get_environment(env_name)
	if not env_value.is_empty():
		return env_value
	var args := OS.get_cmdline_args()
	var flag := "+%s" % arg_name
	for index in args.size():
		if args[index] == flag and index + 1 < args.size():
			return args[index + 1]
	return ""

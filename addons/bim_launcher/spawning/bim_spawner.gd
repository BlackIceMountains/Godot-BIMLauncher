## The script responsible for handling BIM Spawner logic in the game process.
## It is responsible for receiving debugger message, and provides functionality
## for handling teleport.
## -
## Add BIMSpawner.teleport_to_spawn_point(self) to your player node, for it to be teleported to spawn point selected in editor.
extends Node

var spawnpoint_received: bool = false
var spawnpoint_data: BIMSpawnData = null
signal on_spawnpoint_ready

func _ready():
	if EngineDebugger.is_active():
		EngineDebugger.register_message_capture(BIMSpawnDebuggerProtocol.MESSAGE_PREFIX, _on_debugger_message)
		EngineDebugger.send_message(BIMSpawnDebuggerProtocol.MESSAGE_REQUEST_SPAWNPOINT, [])

func _on_debugger_message(message: String, data: Array) -> bool:
	match message:
		# Godot, why here we just get postfix...?!
		BIMSpawnDebuggerProtocol.MESSAGE_ID_SPAWNPOINT:
			assert(spawnpoint_received == false)
			spawnpoint_received = true
			spawnpoint_data = null
			if data.size() > 0:
				spawnpoint_data = BIMSpawnData.new()
				spawnpoint_data.deserialize(data[0])
			on_spawnpoint_ready.emit()
			return true
	return false

func wait_spawnpoint_data_ready():
	if not spawnpoint_received:
		await on_spawnpoint_ready

func teleport_to_spawn_point(node: Node3D):
	if not OS.has_feature("editor"):
		return

	await wait_spawnpoint_data_ready()

	if spawnpoint_data != null:
		print("Teleporting player to spawn point")
		node.global_position = spawnpoint_data.transform.origin
		node.global_rotation.y = spawnpoint_data.transform.basis.get_euler().y

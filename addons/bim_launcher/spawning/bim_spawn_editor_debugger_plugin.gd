@tool
extends EditorDebuggerPlugin

var spawn_point_provider = null # TODO: Can I do it better? Some wrapper type?

func _has_capture(prefix):
	return prefix == BIMSpawnDebuggerProtocol.MESSAGE_PREFIX

func _capture(message: String, data: Array, session_id: int) -> bool:
	match message:
		BIMSpawnDebuggerProtocol.MESSAGE_REQUEST_SPAWNPOINT:
			var payload: Array = []
			var spawn_point : BIMSpawnData = spawn_point_provider.get_spawn_point()
			if spawn_point != null:
				payload.append(spawn_point.serialize())

			get_session(session_id).send_message(BIMSpawnDebuggerProtocol.MESSAGE_SPAWNPOINT, payload)
			return true
	return false

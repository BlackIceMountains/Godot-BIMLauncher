class_name BIMSpawnData

const Default: BIMSpawnData = null
var transform: Transform3D

func serialize():
	var serialized_data: Dictionary
	serialized_data.t = transform
	return serialized_data

func deserialize(data):
	transform = data.t as Transform3D

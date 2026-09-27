extends Node
## Nút RPC cố định tại /root/Game/Network cho cả client và room server (07 §3).
## Chỉ hai RPC, mỗi RPC mang một envelope JSON (String). Không truyền Object/Resource.

signal client_message(peer_id: int, text: String)  ## phía server nhận
signal server_message(text: String)                ## phía client nhận


@rpc("any_peer", "call_remote", "reliable")
func c2s(text: String) -> void:
	if not multiplayer.is_server():
		return
	client_message.emit(multiplayer.get_remote_sender_id(), text)


@rpc("authority", "call_remote", "reliable")
func s2c(text: String) -> void:
	server_message.emit(text)

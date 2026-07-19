# GDScript Security Guide

## Overview

Security considerations for Godot games built with GDScript.

## Input Validation

### User Input

Always validate input from players:

```gdscript
func set_player_name(name: String) -> void:
    # Sanitize input
    var sanitized = name.strip_escapes().left(32)
    sanitized = sanitized.replace("<", "").replace(">", "")
    _player_name = sanitized
```

### File Paths

Validate paths to prevent directory traversal:

```gdscript
func load_save_file(path: String) -> Dictionary:
    # Ensure path is within saves directory
    var safe_path = "user://saves/" + path.get_file()
    if not safe_path.begins_with("user://saves/"):
        push_error("Invalid save path")
        return {}
```

## Secure Networking

### WebSocket Security

```gdscript
func _on_peer_connected(id: int) -> void:
    # Verify peer authentication
    if not _is_authenticated_peer(id):
        peer.disconnect_peer(id)
```

## Anti-Cheat Considerations

- Never trust client-side calculations
- Use server authoritative logic for multiplayer
- Validate game state on server
- Add server-side validation for scores and achievements

## Resource Protection

- Use `.godot/` for user data, not embedded resources
- Encrypt sensitive save data using `EncryptionKey`
- Obfuscate critical game logic when needed

## Dependencies

- Only use trusted plugins from the Asset Library
- Review third-party code before integration
- Keep Godot and plugins updated

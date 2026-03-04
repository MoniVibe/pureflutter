# bullethole_shared

Shared Flutter package for cross-game concerns used by both chess and backgammon clients.

Current contents:
- Reusable UI widgets (`AppAssetIcon`, `CompactModeSwitch`, `GameChatPanel`,
  `CooldownMeter`, `CollapsibleSettingsCard`, `TimeBarOrientationSwitch`)
- Skin model types (board/piece metadata models)
- Multiplayer helpers (`BackendHealthChecker`, `MultiplayerClientUtils`)

The package intentionally contains no game rules or game-specific assets.

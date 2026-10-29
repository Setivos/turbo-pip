class_name WorldData
extends RefCounted
## Static game data: worlds, skins and shared constants.

const T := 24          # tile size in world units
const VH := 360.0      # virtual screen height
const ROWS := 15
const LEVELS_PER_WORLD := 4

static var WORLDS: Array = [
	{"name": "Prairie Douce", "short": "Collines et papillons",
	 "sky": [Color("#8fd3ff"), Color("#d8f3ff")], "far": Color("#9ad7a0"), "near": Color("#6cc47a"),
	 "top": Color("#5cc45a"), "body": Color("#a8743f"), "body2": Color("#8f5f32"), "pit": null, "speed": 150.0,
	 "feat": ["flat", "gap", "up", "down", "wall", "walker", "ledges", "plats", "spring"]},
	{"name": "Grottes Cristal", "short": "Tunnels et chauves-souris",
	 "sky": [Color("#2d2550"), Color("#4b3b78")], "far": Color("#3a2f63"), "near": Color("#4d3f80"),
	 "top": Color("#8f7ae0"), "body": Color("#4a3b7a"), "body2": Color("#3b2f63"), "pit": null, "speed": 150.0,
	 "feat": ["flat", "gap", "up", "down", "wall", "walker", "tunnel", "bat", "spikes", "falling", "ledges"]},
	{"name": "Désert Solaire", "short": "Dunes et cactus piquants",
	 "sky": [Color("#ffb86b"), Color("#ffe3a8")], "far": Color("#f2c27a"), "near": Color("#e8a85c"),
	 "top": Color("#f6d48f"), "body": Color("#d99a55"), "body2": Color("#c08040"), "pit": null, "speed": 158.0,
	 "feat": ["flat", "gap", "up", "down", "wall", "walker", "spiky", "spikes", "moving", "spring", "plats"]},
	{"name": "Pics Gelés", "short": "Glace fragile et vent froid",
	 "sky": [Color("#a8c8ff"), Color("#eef5ff")], "far": Color("#c9dcf5"), "near": Color("#a9c4ea"),
	 "top": Color("#ffffff"), "body": Color("#8fb4e0"), "body2": Color("#7aa0cf"), "pit": null, "speed": 165.0,
	 "feat": ["flat", "gap", "up", "down", "wall", "walker", "spiky", "falling", "moving", "bat", "ledges", "plats"]},
	{"name": "Forteresse de Lave", "short": "Geysers de feu",
	 "sky": [Color("#3a1020"), Color("#7a2a2a")], "far": Color("#5a1f2a"), "near": Color("#6e2a2f"),
	 "top": Color("#8a8a99"), "body": Color("#55505f"), "body2": Color("#46424f"), "pit": Color("#ff6a1f"), "speed": 165.0,
	 "feat": ["flat", "gap", "up", "down", "wall", "walker", "spiky", "spikes", "fire", "falling", "moving", "bat"]},
	{"name": "Royaume des Nuages", "short": "Sauts au-dessus du vide",
	 "sky": [Color("#6ec6ff"), Color("#ffe1f0")], "far": Color("#ffffff"), "near": Color("#f3e6ff"),
	 "top": Color("#fffaf0"), "body": Color("#e6dcff"), "body2": Color("#d6c8f5"), "pit": null, "speed": 170.0,
	 "feat": ["flat", "gap", "clouds", "moving", "spring", "falling", "bat", "walker", "spiky", "ledges"]},
]

static var SKINS: Array = [
	{"id": "menthe", "name": "Menthe", "price": 0, "body": Color("#38d9a9"), "dark": Color("#1b8a6b"), "scarf": Color("#ff6b6b")},
	{"id": "corail", "name": "Corail", "price": 60, "body": Color("#ff8a7a"), "dark": Color("#c2524a"), "scarf": Color("#ffd166")},
	{"id": "prune", "name": "Prune", "price": 120, "body": Color("#a97cff"), "dark": Color("#6a46c2"), "scarf": Color("#38d9a9")},
	{"id": "soleil", "name": "Soleil", "price": 200, "body": Color("#ffd166"), "dark": Color("#c99a2e"), "scarf": Color("#7c5cff")},
	{"id": "nuit", "name": "Nuit", "price": 320, "body": Color("#3b4a7a"), "dark": Color("#222c4f"), "scarf": Color("#ffc83d")},
	{"id": "arc", "name": "Arc-en-ciel", "price": 600, "body": null, "dark": null, "scarf": null},
]

static func world(i: int) -> Dictionary:
	return WORLDS[posmod(i, WORLDS.size())]

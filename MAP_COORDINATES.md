# M# MAP\_COORDINATES.md — Lost Kingdom

# 

# Координаты точек на карте сняты вручную в Godot.

# 

# ВАЖНО:

# \- Не угадывать координаты.

# \- Не двигать точки на глаз.

# \- Если карта заменена, координаты нужно снять заново.

# \- Эти координаты должны совпадать с координатами в `Main.gd`.

# 

# \## Точки карты

# 

# | ID | Название | X | Y |

# |---|---|---:|---:|

# | Castle | Королевский замок | -1112 | -704 |

# | Village | Деревня | -928 | -504 |

# | Dock | Пристань | -1160 | -128 |

# | KnightRuins | Руины рыцарей | -648 | -288 |

# | MageTower | Башня мага | -560 | -320 |

# | EarthMageCastle | Замок мага земли | -464 | -488 |

# | DarkCastle | Замок тьмы | -376 | -568 |

# | Lumbermill | Лесопилка | -640 | -752 |

# | Mine | Заброшенная шахта | -392 | -832 |

# 

# \## Формат для Godot

# 

# ```gdscript

# const WAYPOINTS = {

# &#x09;"Castle": {

# &#x09;	"title": "Королевский замок",

# &#x09;	"position": Vector2(-1112, -704)

# &#x09;},

# &#x09;"Village": {

# &#x09;	"title": "Деревня",

# &#x09;	"position": Vector2(-928, -504)

# &#x09;},

# &#x09;"Dock": {

# &#x09;	"title": "Пристань",

# &#x09;	"position": Vector2(-1160, -128)

# &#x09;},

# &#x09;"KnightRuins": {

# &#x09;	"title": "Руины рыцарей",

# &#x09;	"position": Vector2(-648, -288)

# &#x09;},

# &#x09;"MageTower": {

# &#x09;	"title": "Башня мага",

# &#x09;	"position": Vector2(-560, -320)

# &#x09;},

# &#x09;"EarthMageCastle": {

# &#x09;	"title": "Замок мага земли",

# &#x09;	"position": Vector2(-464, -488)

# &#x09;},

# &#x09;"DarkCastle": {

# &#x09;	"title": "Замок тьмы",

# &#x09;	"position": Vector2(-376, -568)

# &#x09;},

# &#x09;"Lumbermill": {

# &#x09;	"title": "Лесопилка",

# &#x09;	"position": Vector2(-640, -752)

# &#x09;},

# &#x09;"Mine": {

# &#x09;	"title": "Заброшенная шахта",

# &#x09;	"position": Vector2(-392, -832)

# &#x09;}

# }
const WAYPOINT_CONNECTIONS = {
	"Castle": ["Village"],
	"Village": ["Castle", "Dock", "KnightRuins", "Lumbermill"],
	"Dock": ["Village"],
	"KnightRuins": ["Village", "MageTower", "EarthMageCastle"],
	"MageTower": ["KnightRuins"],
	"EarthMageCastle": ["KnightRuins", "DarkCastle", "Mine"],
	"DarkCastle": ["EarthMageCastle"],
	"Lumbermill": ["Village", "Mine"],
	"Mine": ["Lumbermill", "EarthMageCastle"]
}

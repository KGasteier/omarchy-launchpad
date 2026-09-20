// Monogramme fuer Apps ohne Icon - portiert aus omarchy-rofi-placeholder-icons.
//
// Kurzform aus dem App-Namen: Initialen zweier Woerter ("Google Maps" -> "Gm"),
// Binnenmajuskel bei einem Wort ("YouTube" -> "Yt"), sonst die ersten beiden
// Buchstaben ("Hey" -> "He"). Kollisionen werden in natuerlicher Buchstaben-
// folge des letzten Wortes aufgeloest ("Google Maps" neben "Google Messages"
// -> "Ga" / "Gm").
.pragma library

var SKIP = { "the": true, "and": true, "for": true, "of": true }

// Wunsch-Monogramme, Schluessel ist der Icon-Name aus der Desktop-Datei.
var OVERRIDES = {
  "google-messages": "Gm"
}

function words(name) {
  var parts = String(name || "").replace(/[-_]/g, " ").split(/\s+/)
  var out = []
  for (var i = 0; i < parts.length; i++) if (parts[i]) out.push(parts[i])
  return out
}

function monogram(name) {
  var parts = words(name)
  var ws = []
  for (var i = 0; i < parts.length; i++) if (!SKIP[parts[i].toLowerCase()]) ws.push(parts[i])
  if (ws.length === 0) ws = parts
  if (ws.length >= 2) return ws[0].charAt(0).toUpperCase() + ws[1].charAt(0).toLowerCase()
  if (ws.length === 1) {
    var head = ws[0]
    for (var j = 1; j < head.length; j++) {
      var c = head.charAt(j)
      if (c !== c.toLowerCase() && c === c.toUpperCase()) return head.charAt(0).toUpperCase() + c.toLowerCase()
    }
    return head.charAt(0).toUpperCase() + head.substr(1, 1).toLowerCase()
  }
  return "?"
}

function disambiguate(name, mono, used) {
  var ws = words(name)
  var last = ws.length ? ws[ws.length - 1] : String(name)
  var pool = last.substr(1) + (ws.length ? ws[0].substr(1) : "")
  for (var i = 0; i < pool.length; i++) {
    var ch = pool.charAt(i)
    if (!/[A-Za-z]/.test(ch)) continue
    var cand = mono.charAt(0) + ch.toLowerCase()
    if (!used[cand]) return cand
  }
  for (var n = 2; n < 10; n++) {
    var c2 = mono.charAt(0) + n
    if (!used[c2]) return c2
  }
  return mono
}

// Farbton aus dem Icon-Namen - stabil ueber Neustarts, wie in der SVG-Fassung.
function hue(key) {
  var h = 0
  var s = String(key || "")
  for (var i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0
  return h % 360
}

// Weist allen Zeilen ohne Icon ein eindeutiges Monogramm zu.
// rows: [{ label, iconKey, needsMonogram }] - wird in place ergaenzt (mono, hue).
function assign(rows) {
  var used = {}
  for (var k in OVERRIDES) used[OVERRIDES[k]] = k
  for (var i = 0; i < rows.length; i++) {
    var r = rows[i]
    if (!r.needsMonogram) continue
    var m = OVERRIDES[r.iconKey] || monogram(r.label)
    if (used[m] && used[m] !== r.iconKey) m = disambiguate(r.label, m, used)
    used[m] = r.iconKey
    r.mono = m
    r.hue = hue(r.iconKey || r.label)
  }
}

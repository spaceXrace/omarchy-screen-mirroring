function parseJson(raw, fallback) {
  try { return JSON.parse(String(raw || "")) } catch (e) { return fallback }
}

function safeRemoteText(value, maximumLength) {
  var limit = maximumLength || 160
  return String(value || "")
    .replace(/[\u0000-\u001f\u007f]/g, " ")
    .replace(/[<>]/g, "")
    .slice(0, limit)
}

function deviceSubtitle(device) {
  if (!device) return ""
  var parts = []
  if (device.model) parts.push(safeRemoteText(device.model, 160))
  if (device.ip) parts.push(safeRemoteText(device.ip, 64))
  return parts.join(" · ")
}

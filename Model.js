function parseJson(raw, fallback) {
  try { return JSON.parse(String(raw || "")) } catch (e) { return fallback }
}

function deviceSubtitle(device) {
  if (!device) return ""
  var parts = []
  if (device.model) parts.push(device.model)
  if (device.ip) parts.push(device.ip)
  return parts.join(" · ")
}

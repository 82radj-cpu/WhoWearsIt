local _, ns = ...
-- Applies to esMX and esES clients; esES.lua then overrides the few words that differ.
local locale = GetLocale()
if locale ~= "esMX" and locale ~= "esES" then return end

ns.ES_STRINGS = {
  ["Who Wears It"] = "Who Wears It",
  ["Only missing"] = "Sólo las que faltan",
  ["Usable by:"] = "Usable por:",
  ["All characters"] = "Todos",
  ["Search"] = "Buscar",
  ["Cloth"] = "Tela", ["Leather"] = "Cuero", ["Mail"] = "Malla", ["Plate"] = "Placas",
  ["Undress"] = "Desvestir",
  ["Who can wear it"] = "Quién la puede usar",
  ["Add to look"] = "Añadir al look",
  ["Loading…"] = "Cargando…",
  ["Collected %d of %d"] = "Tienes %d de %d",
  ["Missing %d"] = "Te faltan %d",
  ["Level %d"] = "Nivel %d",
  ["Does not use %s"] = "No usa %s",
  ["Class only"] = "Sólo para otra clase",
  ["Unknown"] = "Sin datos",
  ["No characters yet. Log in with each of your characters once."] =
    "Aún no hay personajes. Entra una vez con cada uno.",
  ["Select an appearance."] = "Elige una apariencia.",
  ["Fake data mode: %s"] = "Datos de prueba: %s",
  ["Log in with a character that wears %s to fill this list."] =
    "Entra con un personaje que use %s para llenar esta lista.",
  ["Commands:"] = "Comandos:",
  ["/wwi - open or close the window"] = "/wwi - abre o cierra la ventana",
  ["/wwi missing - open showing only missing appearances"] = "/wwi missing - abre con sólo las que faltan",
  ["/wwi roster - list your recorded characters"] = "/wwi roster - lista tus personajes apuntados",
  ["/wwi forget <name> - remove a character from the roster"] = "/wwi forget <nombre> - quita un personaje",
  ["/wwi minimap - show or hide the minimap button"] = "/wwi minimap - muestra u oculta el botón del minimapa",
  ["/wwi selftest - run the diagnostics and save them"] = "/wwi selftest - corre el diagnóstico y lo guarda",
  ["/wwi debug - toggle debug messages"] = "/wwi debug - mensajes de depuración",
  ["/wwi help - this list"] = "/wwi help - esta lista",
  ["Recorded characters:"] = "Personajes apuntados:",
  ["No character named %s."] = "No hay ningún personaje llamado %s.",
  ["Type /wwi forget %s again within 10 seconds to confirm."] =
    "Escribe /wwi forget %s otra vez antes de 10 segundos para confirmar.",
  ["Removed %s."] = "Se quitó a %s.",
  ["Minimap button: %s"] = "Botón del minimapa: %s",
  ["Debug: %s"] = "Depuración: %s",
  ["on"] = "sí", ["off"] = "no",
  ["Self-test: %d OK, %d FAIL. Saved; /reload writes it to disk."] =
    "Diagnóstico: %d OK, %d FALLA. Guardado; /reload lo escribe a disco.",
  ["Not in combat. Try again after the fight."] = "En combate no. Inténtalo al terminar la pelea.",
  ["Left-click: open or close"] = "Clic izquierdo: abrir o cerrar",
  ["New look"] = "Look nuevo",
  ["%d of %d"] = "%d de %d",
  ["Strategy: %s"] = "Estrategia: %s",
}

for k, v in pairs(ns.ES_STRINGS) do ns.L[k] = v end

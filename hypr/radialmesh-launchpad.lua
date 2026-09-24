-- Radial Mesh Launchpad: Tastenbindung fuer das App-Raster-Overlay.
-- SUPER + R: das Launchpad erbt die Taste des Originals, sobald dieses
-- deinstalliert ist. Zwei Bindungen auf SUPER + R darf es nicht geben.
-- Mit Vorauswahl eines Typs, z. B. nur Agents:
--   omarchy-shell shell toggle community.radialmesh-launchpad '{"type":"ai"}'
o.bind("SUPER + R", "Launchpad", "omarchy-shell shell toggle community.radialmesh-launchpad")

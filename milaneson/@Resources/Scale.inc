; Escala de la interfaz. Se incluye DESPUÉS de Settings.inc (usa UIScale).
; UIScale=0 → automático: altura del monitor del widget / 1440 (1080p = 75 %, 4K = 150 %),
; limitado entre 70 % y 200 %. Cualquier otro valor es fijo (0.75, 1, 1.25…).
; Rainmeter refresca las skins al cambiar la resolución, así que se recalcula solo.
[Variables]
S=(#UIScale#+(1-Sgn(#UIScale#))*Clamp(#SCREENAREAHEIGHT#/1440,0.7,2))
Radius=(10*#S#)
Pad=(12*#S#)

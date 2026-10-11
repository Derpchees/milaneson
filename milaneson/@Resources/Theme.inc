; Sistema de diseño compartido por toda la suite milaneson.
; Los valores que cambia el Hub viven en Settings.inc, no aquí.
; El idioma (textos, Locale, formato de fecha) está en Lang\es.inc / Lang\en.inc

[Variables]
; Superficies: tarjeta oscura translúcida con borde finísimo
PanelColor=22,22,26,215
HubColor=22,22,26,245
BorderColor=255,255,255,20
; Radius y Pad están en Scale.inc (dependen de la escala)

; Texto
TextColor=255,255,255,240
MutedColor=255,255,255,150
SubtleColor=255,255,255,38
FontName=Segoe UI Variable Text
DisplayFont=Segoe UI Variable Display
; Iconos nativos de Windows 11
IconFont=Segoe Fluent Icons

; Paleta de acentos que ofrece el Hub (AccentIndex 0-4)
Acc0=130,205,255,255
Acc1=190,118,255,255
Acc2=110,231,150,255
Acc3=255,170,90,255
Acc4=255,120,170,255

; Formatos de hora según Use24h (se leen como [#ClockFmt[#Use24h]])
ClockFmt0=%#I:%M
ClockFmt1=%H:%M

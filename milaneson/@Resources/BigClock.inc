; Cuerpo del reloj grande. Lo usan BigClock y BigClock2; cada uno define #Scale# y #StateKey#.

[MeasureTime]
Measure=Time
Format=[#ClockFmt[#Use24h]]
DynamicVariables=1

[MeasureSeconds]
Measure=Time
Format=%S

[MeasureAmPm]
Measure=Time
Format=%p
FormatLocale=#Locale#

[MeasureDate]
Measure=Time
Format=#BigDateFmt#
FormatLocale=#Locale#

[StyleShadow]
AntiAlias=1
InlineSetting=Shadow | 0 | 1 | 4 | 0,0,0,110

[MeterTime]
Meter=String
MeterStyle=StyleShadow
MeasureName=MeasureTime
X=0
Y=0
FontFace=#DisplayFont#
FontWeight=300
FontSize=(64*#Scale#)
FontColor=#ClockText#
DynamicVariables=1

; Columna a la derecha de la hora: segundos arriba, a. m./p. m. abajo
[MeterSeconds]
Meter=String
MeterStyle=StyleShadow
MeasureName=MeasureSeconds
X=(6*#Scale#)R
Y=(24*#Scale#)r
FontFace=#DisplayFont#
FontWeight=400
FontSize=(18*#Scale#)
FontColor=#ClockAccent#
Hidden=(1-#ShowSeconds#)
DynamicVariables=1

[MeterAmPm]
Meter=String
MeterStyle=StyleShadow
MeasureName=MeasureAmPm
X=r
Y=(28*#Scale#)r
FontFace=#FontName#
FontWeight=600
FontSize=(10*#Scale#)
FontColor=#ClockText#
DynamicVariables=1
Hidden=#Use24h#

[MeterDate]
Meter=String
MeterStyle=StyleShadow
MeasureName=MeasureDate
X=(6*#Scale#)
Y=([MeterTime:Y]+[MeterTime:H]-(14*#Scale#))
DynamicVariables=1
FontFace=#FontName#
FontWeight=500
FontSize=(13*#Scale#)
FontColor=#ClockAccent#
Hidden=(1-#ShowDate#)

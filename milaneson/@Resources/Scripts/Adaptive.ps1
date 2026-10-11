# Color de acento adaptativo para milaneson.
# Captura el fondo de pantalla del monitor principal (también fondos animados de
# Wallpaper Engine / Lively), calcula un color vivo y legible, y lo manda a Rainmeter.
#   -Once     calcula una vez, imprime "R,G,B,255" y sale (para pruebas)
#   (normal)  bucle en segundo plano; sale si Rainmeter se cierra o si en el Hub
#             se elige un color fijo (AccentIndex distinto de 5 en Settings.inc)
param(
    [string]$Config = 'milaneson\Adaptive',
    [string]$Settings = '',
    [int]$AnimatedSeconds = 4,
    [int]$StaticSeconds = 5,
    [switch]$Once
)

$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Text;

public static class MilaAccent {
    delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
    [DllImport("user32.dll")] static extern bool IsWindow(IntPtr h);
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int L, T, R, B; }

    const int SW = 96, SH = 54;   // tamaño de muestreo
    static IntPtr cached = IntPtr.Zero;

    // Ventanas que pueden contener el fondo: Progman (Win11 24H2+) y WorkerW (anteriores)
    static List<IntPtr> Candidates() {
        var list = new List<IntPtr>();
        if (cached != IntPtr.Zero && IsWindow(cached)) list.Add(cached);
        EnumWindows((h, l) => {
            var sb = new StringBuilder(32); GetClassName(h, sb, 32);
            string c = sb.ToString();
            if (c == "Progman" || c == "WorkerW") {
                RECT r; GetWindowRect(h, out r);
                if (r.R - r.L > 200 && r.B - r.T > 200 && h != cached) list.Add(h);
            }
            return true;
        }, IntPtr.Zero);
        return list;
    }

    // Captura la parte de la ventana que cae en el rectángulo de pantalla 'area'
    static Bitmap CaptureWindow(IntPtr h, Rectangle area) {
        RECT r; if (!GetWindowRect(h, out r)) return null;
        int w = r.R - r.L, hh = r.B - r.T;
        if (w <= 0 || hh <= 0) return null;
        using (var full = new Bitmap(w, hh)) {
            using (var g = Graphics.FromImage(full)) {
                IntPtr hdc = g.GetHdc();
                bool ok = PrintWindow(h, hdc, 2);   // PW_RENDERFULLCONTENT
                g.ReleaseHdc(hdc);
                if (!ok) return null;
            }
            var src = new Rectangle(area.X - r.L, area.Y - r.T, area.Width, area.Height);
            src.Intersect(new Rectangle(0, 0, w, hh));
            if (src.Width <= 0 || src.Height <= 0) return null;
            return Shrink(full, src);
        }
    }

    public static Bitmap Shrink(Image img, Rectangle src) {
        var small = new Bitmap(SW, SH);
        using (var g = Graphics.FromImage(small)) {
            g.InterpolationMode = InterpolationMode.Bilinear;
            g.DrawImage(img, new Rectangle(0, 0, SW, SH), src, GraphicsUnit.Pixel);
        }
        return small;
    }

    static double LitFraction(Bitmap b) {
        int lit = 0, n = 0;
        for (int x = 0; x < b.Width; x += 3) for (int y = 0; y < b.Height; y += 3) {
            Color c = b.GetPixel(x, y); n++;
            if (c.R + c.G + c.B > 45) lit++;
        }
        return n == 0 ? 0 : (double)lit / n;
    }

    // Fondo animado: devuelve la primera ventana de fondo que no salga negra
    public static Bitmap CaptureDesktop(Rectangle area) {
        foreach (var h in Candidates()) {
            var b = CaptureWindow(h, area);
            if (b == null) continue;
            if (LitFraction(b) > 0.02) { cached = h; return b; }
            b.Dispose();
        }
        return null;
    }

    static void ToHsv(Color c, out double h, out double s, out double v) {
        double r = c.R / 255.0, g = c.G / 255.0, b = c.B / 255.0;
        double max = Math.Max(r, Math.Max(g, b)), min = Math.Min(r, Math.Min(g, b)), d = max - min;
        v = max; s = max == 0 ? 0 : d / max;
        if (d == 0) h = 0;
        else if (max == r) h = 60 * (((g - b) / d) % 6);
        else if (max == g) h = 60 * ((b - r) / d + 2);
        else h = 60 * ((r - g) / d + 4);
        if (h < 0) h += 360;
    }

    static int[] FromHsv(double h, double s, double v) {
        double c = v * s, x = c * (1 - Math.Abs((h / 60) % 2 - 1)), m = v - c, r = 0, g = 0, b = 0;
        if (h < 60) { r = c; g = x; } else if (h < 120) { r = x; g = c; } else if (h < 180) { g = c; b = x; }
        else if (h < 240) { g = x; b = c; } else if (h < 300) { r = x; b = c; } else { r = c; b = x; }
        return new[] { (int)Math.Round((r + m) * 255), (int)Math.Round((g + m) * 255), (int)Math.Round((b + m) * 255) };
    }

    // Color vivo dominante, ajustado para leerse sobre tarjetas oscuras
    public static string Accent(Bitmap b) {
        const int BINS = 36;
        var weight = new double[BINS]; var sr = new double[BINS]; var sg = new double[BINS]; var sb = new double[BINS];
        double total = 0;
        for (int x = 0; x < b.Width; x++) for (int y = 0; y < b.Height; y++) {
            Color c = b.GetPixel(x, y);
            double h, s, v; ToHsv(c, out h, out s, out v);
            if (v < 0.18 || s < 0.22) continue;
            double w = s * s * v;
            int i = (int)(h / 10) % BINS;
            weight[i] += w; sr[i] += c.R * w; sg[i] += c.G * w; sb[i] += c.B * w; total += w;
        }
        if (total < 1.5) return "200,206,216,255";   // fondo casi gris: acento neutro
        int best = 0; double bestW = -1;
        for (int i = 0; i < BINS; i++) {
            double w = weight[i] + 0.5 * (weight[(i + 1) % BINS] + weight[(i + BINS - 1) % BINS]);
            if (w > bestW) { bestW = w; best = i; }
        }
        double W = 0, R = 0, G = 0, B = 0;
        for (int k = -1; k <= 1; k++) { int i = (best + k + BINS) % BINS; W += weight[i]; R += sr[i]; G += sg[i]; B += sb[i]; }
        Color avg = Color.FromArgb((int)(R / W), (int)(G / W), (int)(B / W));
        double hh, ss, vv; ToHsv(avg, out hh, out ss, out vv);
        ss = Math.Max(0.40, Math.Min(0.75, ss));
        vv = 0.96;
        int[] o = FromHsv(hh, ss, vv);
        return o[0] + "," + o[1] + "," + o[2] + ",255";
    }

    // Para texto sin tarjeta (relojes grandes): tono complementario al acento y
    // texto claro u oscuro según el brillo medio del fondo. Devuelve "acento|texto".
    public static string Contrast(Bitmap b, string accent) {
        double lum = 0; int n = 0;
        for (int x = 0; x < b.Width; x++) for (int y = 0; y < b.Height; y++) {
            Color c = b.GetPixel(x, y); n++;
            lum += (0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B) / 255.0;
        }
        lum = n == 0 ? 0 : lum / n;
        bool dark = lum < 0.55;
        string[] p = accent.Split(',');
        double h, s, v; ToHsv(Color.FromArgb(int.Parse(p[0]), int.Parse(p[1]), int.Parse(p[2])), out h, out s, out v);
        bool neutral = accent.StartsWith("200,206,216");
        double ch = (h + 180) % 360;
        int[] o = neutral ? (dark ? new[] { 130, 205, 255 } : new[] { 30, 60, 110 })
                          : FromHsv(ch, dark ? 0.55 : 0.85, dark ? 1.0 : 0.38);
        string text = dark ? "255,255,255,230" : "20,20,24,230";
        return o[0] + "," + o[1] + "," + o[2] + ",255|" + text;
    }
}
"@

$primary = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$rainmeter = Join-Path $env:ProgramFiles 'Rainmeter\Rainmeter.exe'
$animatedProcs = 'wallpaper32', 'wallpaper64', 'Lively', 'livelywpf', 'DeskScapes', 'WallpaperEngine'

function Get-StaticWallpaper {
    $p = (Get-ItemProperty 'HKCU:\Control Panel\Desktop').WallPaper
    if (-not $p -or -not (Test-Path $p)) { $p = "$env:APPDATA\Microsoft\Windows\Themes\TranscodedWallpaper" }
    if (Test-Path $p) { return Get-Item $p }
    return $null
}

$lastStaticKey = ''; $lastSent = ''
function Get-AccentNow {
    $animated = [bool](Get-Process -Name $animatedProcs)
    if ($animated) {
        $b = [MilaAccent]::CaptureDesktop($primary)
        if ($b) { $a = [MilaAccent]::Accent($b); $k = [MilaAccent]::Contrast($b, $a); $b.Dispose(); return @($a, $true, $k) }
    }
    $f = Get-StaticWallpaper
    if (-not $f) { return @($null, $false) }
    $key = "$($f.FullName)|$($f.LastWriteTimeUtc.Ticks)"
    if (-not $Once -and $key -eq $script:lastStaticKey) { return @($null, $false) }
    $script:lastStaticKey = $key
    try {
        $img = [System.Drawing.Image]::FromFile($f.FullName)
        $b = [MilaAccent]::Shrink($img, (New-Object System.Drawing.Rectangle 0, 0, $img.Width, $img.Height))
        $img.Dispose()
        $a = [MilaAccent]::Accent($b); $k = [MilaAccent]::Contrast($b, $a); $b.Dispose(); return @($a, $false, $k)
    } catch { return @($null, $false) }
}

function Distance($a, $b) {
    if (-not $a -or -not $b) { return 999 }
    $x = $a.Split(','); $y = $b.Split(',')
    return [math]::Abs([int]$x[0] - [int]$y[0]) + [math]::Abs([int]$x[1] - [int]$y[1]) + [math]::Abs([int]$x[2] - [int]$y[2])
}

if ($Once) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $r = Get-AccentNow
    Write-Output ("acento={0}  reloj={1}  (animado={2}, {3} ms)" -f $r[0], $r[2], $r[1], $sw.ElapsedMilliseconds)
    exit 0
}

# Una sola instancia
$mutex = New-Object System.Threading.Mutex($false, 'Local\milaneson-adaptive')
if (-not $mutex.WaitOne(0)) { exit 0 }

while ($true) {
    if (-not (Get-Process Rainmeter)) { break }
    if ($Settings -and (Test-Path $Settings)) {
        $idx = (Get-Content $Settings -Encoding Unicode | Where-Object { $_ -match '^AccentIndex=' }) -replace '^AccentIndex=', ''
        if ($idx -and $idx.Trim() -ne '5') { break }
    }
    $r = Get-AccentNow
    if ($r[0] -and (Distance $r[0] $lastSent) -gt 18) {
        $k = $r[2].Split('|')
        & $rainmeter '!SetVariable' 'NewClockAccent' $k[0] $Config
        & $rainmeter '!SetVariable' 'NewClockText' $k[1] $Config
        & $rainmeter '!SetVariable' 'NewAccent' $r[0] $Config
        $lastSent = $r[0]
    }
    if ($r[1]) { Start-Sleep -Seconds $AnimatedSeconds } else { Start-Sleep -Seconds $StaticSeconds }
}
$mutex.ReleaseMutex()

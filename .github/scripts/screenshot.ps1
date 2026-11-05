# Elindítja a programot, és képernyőképet készít az ablakáról (CI-ellenőrzéshez)
param([string]$Exe, [string]$Out)

Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Win {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
"@

$p = Start-Process -FilePath $Exe -PassThru
$hwnd = [IntPtr]::Zero
for ($i = 0; $i -lt 60 -and $hwnd -eq [IntPtr]::Zero; $i++) {
  Start-Sleep -Milliseconds 500
  $p.Refresh()
  $hwnd = $p.MainWindowHandle
}
if ($hwnd -eq [IntPtr]::Zero) { throw "A program ablaka nem jelent meg" }
Start-Sleep -Seconds 6
[Win]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Seconds 1

$r = New-Object Win+RECT
[Win]::GetWindowRect($hwnd, [ref]$r) | Out-Null
$w = $r.R - $r.L; $h = $r.B - $r.T
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
[Win]::PrintWindow($hwnd, $hdc, 2) | Out-Null   # PW_RENDERFULLCONTENT: GPU-tartalom is
$g.ReleaseHdc($hdc)
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "Képernyőkép: $Out ($w x $h)"

if ($p.HasExited) { throw "A program kilépett (kód: $($p.ExitCode))" }
Stop-Process -Id $p.Id -Force

# A kép a naplóba is bekerül (base64, JPEG), hogy a futás naplójából is visszanézhető legyen
$jpg = [System.IO.Path]::ChangeExtension($Out, '.jpg')
$enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 80L
$bmp.Save($jpg, $enc, $ep)
$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($jpg))
Write-Host "SCREENSHOT-BEGIN"
for ($k = 0; $k -lt $b64.Length; $k += 3000) { Write-Host ("B64:" + $b64.Substring($k, [Math]::Min(3000, $b64.Length - $k))) }
Write-Host "SCREENSHOT-END"

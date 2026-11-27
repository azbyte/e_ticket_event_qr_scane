# Menghasilkan template desain tiket PNG (LATAR/ARTWORK saja) untuk kedua orientasi:
#   - ticket-template-landscape.png (1684 x 1188 px = 2x kanvas 842 x 594 pt)
#   - ticket-template-portrait.png  ( 880 x 1408 px = 2x kanvas 440 x 704 pt)
#
# Template ini adalah kanvas desain: HANYA berisi latar, ornamen, dan penanda
# TIPIS area QR (garis putus-putus tanpa alas putih dan tanpa teks). Teks
# peserta/event TIDAK dicetak di sini karena ditulis dinamis oleh backend
# (`ticketDesignService`) saat tiket dirender — sehingga Organizer yang
# mengunggah template ini tidak menghasilkan teks/alas putih ganda.
#
# Ukuran/posisi HARUS konsisten dengan `backend/src/services/ticketDesignService.js`
# (LANDSCAPE_CANVAS / PORTRAIT_CANVAS + DEFAULT_QR_BY_ORIENTATION:
#  landscape QR kiri 6.65%, atas 47.81%, sisi 37.04% tinggi kanvas (220 pt);
#  portrait  QR kiri 8.18%, atas 37.78%, sisi 35.51% tinggi kanvas (250 pt)).
#
# Jalankan dari root repository:
#   powershell -ExecutionPolicy Bypass -File backend/scripts/generate-ticket-template.ps1
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$outDir = Join-Path $root 'assets\ticket-templates'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function New-TicketTemplate {
  param(
    [int]$Width,
    [int]$Height,
    [string]$Orientation,
    [string]$OutFile
  )

  $bmp = New-Object System.Drawing.Bitmap $Width, $Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.Clear([System.Drawing.ColorTranslator]::FromHtml('#FFFDF8'))

  $rose900 = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#7A3B38'))
  $rose700 = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#A85C58'))
  $rose300 = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#E7B6B0'))
  $pinkFill = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#EDC3BE'))
  $pinkSoft = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#F7DEDA'))
  $cream = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#FBF2E4'))
  $creamDeep = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#F2E2CA'))

  if ($Orientation -eq 'portrait') {
    # Kanvas 880 x 1408 px (440 x 704 pt). Header pink 504 px = 252 pt.
    $g.FillRectangle($pinkFill, 0, 0, $Width, 504)
    $g.FillEllipse($pinkSoft, $Width - 220, -160, 320, 320)
    $g.FillRectangle($cream, 0, 504, $Width, $Height - 504)
    $g.FillEllipse($creamDeep, $Width - 220, 1080, 260, 260)
    $penSoft = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml('#E7B6B0')), 3
    $g.DrawEllipse($penSoft, -260, 1240, 380, 380)

    # Penanda area QR: kiri 8.18%, atas 37.78%, sisi 35.51% tinggi (500 px).
    $qrX = 72; $qrY = 532; $qrSize = 500
  } else {
    # Kanvas 1684 x 1188 px (842 x 594 pt). Panel kiri 940 px = 470 pt.
    $g.FillRectangle($pinkFill, 0, 0, 940, $Height)
    $g.FillEllipse($pinkSoft, 620, 900, 460, 460)
    $g.FillRectangle($cream, 940, 0, $Width - 940, $Height)
    $g.FillEllipse($creamDeep, $Width - 300, -300, 600, 600)

    $penSoft = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml('#E7B6B0')), 3
    $g.DrawEllipse($penSoft, 1000, 1000, 300, 300)
    $g.DrawEllipse($penSoft, 1040, 1040, 220, 220)
    $g.DrawEllipse($penSoft, 1080, 1080, 140, 140)
    for ($i = 0; $i -lt 5; $i++) {
      $g.FillEllipse($rose300, (1120 + $i * 26), 1150, 10, 10)
    }

    # Penanda area QR: kiri 6.65%, atas 47.81%, sisi 37.04% tinggi (440 px).
    $qrX = 112; $qrY = 568; $qrSize = 440
  }

  # Penanda area QR: garis putus-putus tipis saja. TIDAK ada alas putih dan
  # TIDAK ada teks, agar QR final tidak dikelilingi area putih berlebih.
  $dashPen = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml('#A85C58')), 2
  $dashPen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
  $g.DrawRectangle($dashPen, $qrX, $qrY, $qrSize, $qrSize)

  $bmp.Save($OutFile, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose()
  $bmp.Dispose()
  Write-Output "Template ditulis ke $OutFile ($Width x $Height px)"
}

New-TicketTemplate -Width 1684 -Height 1188 -Orientation 'landscape' `
  -OutFile (Join-Path $outDir 'ticket-template-landscape.png')
New-TicketTemplate -Width 880 -Height 1408 -Orientation 'portrait' `
  -OutFile (Join-Path $outDir 'ticket-template-portrait.png')

# Salinan nama lama agar tautan/template sebelumnya tetap berfungsi.
Copy-Item (Join-Path $outDir 'ticket-template-landscape.png') `
  (Join-Path $outDir 'ticket-template.png') -Force
Write-Output 'Salinan kompatibilitas: ticket-template.png (landscape)'


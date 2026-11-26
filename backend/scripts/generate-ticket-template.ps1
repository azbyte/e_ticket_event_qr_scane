# Menghasilkan template desain tiket PNG untuk kedua orientasi:
#   - ticket-template-landscape.png (1200 x 480 px, rasio 2.5:1)
#   - ticket-template-portrait.png  (  880 x 1408 px, rasio 1:1.6)
#
# Template dipakai Organizer sebagai acuan ukuran dan penanda posisi QR.
# Ukuran/posisi harus konsisten dengan `backend/src/services/ticketDesignService.js`
# (DEFAULT_QR_BY_ORIENTATION: landscape x 74%, y 25%, size 50% tinggi;
#  portrait x 32%, y 66%, size 28% tinggi).
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
  $g.Clear([System.Drawing.Color]::White)

  $bandBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#1E3A8A'))
  $stripBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#EEF2FF'))

  $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
  $lightBlue = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#C7D2FE'))
  $dark = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#111111'))
  $muted = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#374151'))
  $gray = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#6B7280'))

  $fontTitle = New-Object System.Drawing.Font 'Arial', 40, ([System.Drawing.FontStyle]::Bold)
  $fontSub = New-Object System.Drawing.Font 'Arial', 15
  $fontEvent = New-Object System.Drawing.Font 'Arial', 24, ([System.Drawing.FontStyle]::Bold)
  $fontBody = New-Object System.Drawing.Font 'Arial', 14
  $fontSmall = New-Object System.Drawing.Font 'Arial', 10
  $fontQr = New-Object System.Drawing.Font 'Arial', 12, ([System.Drawing.FontStyle]::Bold)

  if ($Orientation -eq 'portrait') {
    $g.FillRectangle($bandBrush, 0, 0, $Width, [int]($Height * 0.11))
    $g.DrawString('E-TICKET', $fontTitle, $white, 70, 40)
    $g.DrawString('E-Ticket Event Platform', $fontSub, $lightBlue, 72, 100)

    $g.DrawString('Nama Event', $fontEvent, $dark, 70, [int]($Height * 0.16))
    $g.DrawString('Nama Peserta', $fontBody, $muted, 70, [int]($Height * 0.16) + 44)
    $g.DrawString('Kategori Tiket', $fontBody, $muted, 70, [int]($Height * 0.16) + 68)
    $g.DrawString('Tanggal & lokasi event', $fontBody, $muted, 70, [int]($Height * 0.16) + 92)
    $g.DrawString('Kode tiket', $fontBody, $muted, 70, [int]($Height * 0.16) + 116)

    # Penanda area QR: x = 32% lebar, y = 66% tinggi, sisi = 28% tinggi.
    $qrX = [int]($Width * 0.32)
    $qrY = [int]($Height * 0.66)
    $qrSize = [int]($Height * 0.28)
    $noteX = 70
    $noteY = [int]($Height * 0.955)
  } else {
    $g.FillRectangle($bandBrush, 0, 0, [int]($Width * 0.3), $Height)
    $g.FillRectangle($stripBrush, [int]($Width * 0.3), 0, $Width - [int]($Width * 0.3), [int]($Height * 0.12))
    $g.DrawString('E-TICKET', $fontTitle, $white, 40, 60)
    $g.DrawString('E-Ticket Event Platform', $fontSub, $lightBlue, 40, 118)

    $g.DrawString('Nama Event', $fontEvent, $dark, [int]($Width * 0.34), [int]($Height * 0.2))
    $g.DrawString('Nama Peserta', $fontBody, $muted, [int]($Width * 0.34), [int]($Height * 0.2) + 44)
    $g.DrawString('Kategori Tiket', $fontBody, $muted, [int]($Width * 0.34), [int]($Height * 0.2) + 68)
    $g.DrawString('Tanggal & lokasi event', $fontBody, $muted, [int]($Width * 0.34), [int]($Height * 0.2) + 92)
    $g.DrawString('Kode tiket', $fontBody, $muted, [int]($Width * 0.34), [int]($Height * 0.2) + 116)

    # Penanda area QR: x = 74% lebar, y = 25% tinggi, sisi = 50% tinggi.
    $qrX = [int]($Width * 0.74)
    $qrY = [int]($Height * 0.25)
    $qrSize = [int]($Height * 0.5)
    $noteX = [int]($Width * 0.34)
    $noteY = [int]($Height * 0.9)
  }

  $dashPen = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml('#9CA3AF')), 2
  $dashPen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
  $g.DrawRectangle($dashPen, $qrX, $qrY, $qrSize, $qrSize)
  $qrFormat = New-Object System.Drawing.StringFormat
  $qrFormat.Alignment = [System.Drawing.StringAlignment]::Center
  $qrFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
  $qrRect = New-Object System.Drawing.RectangleF $qrX, $qrY, $qrSize, $qrSize
  $g.DrawString('AREA QR', $fontQr, $gray, $qrRect, $qrFormat)

  $g.DrawString(
    "Template $Width x $Height px ($Orientation). Jangan menutup area QR. Informasi peserta dicetak di area teks.",
    $fontSmall, $gray, $noteX, $noteY)

  $bmp.Save($OutFile, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose()
  $bmp.Dispose()
  Write-Output "Template ditulis ke $OutFile"
}

New-TicketTemplate -Width 1200 -Height 480 -Orientation 'landscape' `
  -OutFile (Join-Path $outDir 'ticket-template-landscape.png')
New-TicketTemplate -Width 880 -Height 1408 -Orientation 'portrait' `
  -OutFile (Join-Path $outDir 'ticket-template-portrait.png')

# Salinan nama lama agar tautan/template sebelumnya tetap berfungsi.
Copy-Item (Join-Path $outDir 'ticket-template-landscape.png') `
  (Join-Path $outDir 'ticket-template.png') -Force
Write-Output 'Salinan kompatibilitas: ticket-template.png (landscape)'


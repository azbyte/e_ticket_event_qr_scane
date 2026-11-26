# Menghasilkan template desain tiket PNG (1200 x 480 px).
#
# Template dipakai Organizer sebagai acuan ukuran dan penanda posisi QR.
# Ukuran/posisi harus konsisten dengan `backend/src/services/ticketDesignService.js`
# (DEFAULT_QR = x 74%, y 25%, size 50% tinggi kanvas).
#
# Jalankan dari root repository:
#   powershell -ExecutionPolicy Bypass -File backend/scripts/generate-ticket-template.ps1
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$outDir = Join-Path $root 'assets\ticket-templates'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outFile = Join-Path $outDir 'ticket-template.png'

$width = 1200
$height = 480
$bmp = New-Object System.Drawing.Bitmap $width, $height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::White)

$bandBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#1E3A8A'))
$stripBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#EEF2FF'))
$g.FillRectangle($bandBrush, 0, 0, 360, $height)
$g.FillRectangle($stripBrush, 360, 0, $width - 360, 58)

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

$g.DrawString('E-TICKET', $fontTitle, $white, 40, 60)
$g.DrawString('E-Ticket Event Platform', $fontSub, $lightBlue, 40, 118)

$g.DrawString('Nama Event', $fontEvent, $dark, 408, 96)
$g.DrawString('Nama Peserta', $fontBody, $muted, 408, 140)
$g.DrawString('Kategori Tiket', $fontBody, $muted, 408, 164)
$g.DrawString('Tanggal & lokasi event', $fontBody, $muted, 408, 188)
$g.DrawString('Kode tiket', $fontBody, $muted, 408, 212)

# Penanda area QR: x = 74% lebar, y = 25% tinggi, sisi = 50% tinggi.
$qrX = [int]($width * 0.74)
$qrY = [int]($height * 0.25)
$qrSize = [int]($height * 0.5)
$dashPen = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml('#9CA3AF')), 2
$dashPen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$g.DrawRectangle($dashPen, $qrX, $qrY, $qrSize, $qrSize)
$qrFormat = New-Object System.Drawing.StringFormat
$qrFormat.Alignment = [System.Drawing.StringAlignment]::Center
$qrFormat.LineAlignment = [System.Drawing.StringAlignment]::Center
$qrRect = New-Object System.Drawing.RectangleF $qrX, $qrY, $qrSize, $qrSize
$g.DrawString('AREA QR', $fontQr, $gray, $qrRect, $qrFormat)

$g.DrawString('Template 1200 x 480 px. Jangan menutup area QR. Informasi peserta dicetak di area teks.',
  $fontSmall, $gray, 408, 430)

$bmp.Save($outFile, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
Write-Output "Template ditulis ke $outFile"

# PRODUCT REQUIREMENTS DOCUMENT (PRD)

# E-Ticket Event Platform

-   **Versi:** 1.1 --- Penyesuaian fokus pengembangan frontend
-   **Status:** Acuan desain UI/UX dan prototype frontend
-   **Tahap saat ini:** Pengembangan tampilan aplikasi menggunakan data dummy
-   **Platform:** Flutter Android dan Flutter Web
-   **Backend saat ini:** Belum digunakan
-   **Rencana backend berikutnya:** Node.js + Express
-   **Rencana database berikutnya:** PostgreSQL dengan Prisma ORM
-   **Target pasar awal:** Indonesia
-   **Bahasa antarmuka:** Bahasa Indonesia
-   **Model role:** Participant, Organizer, Admin
-   **Model pembayaran MVP:** Simulasi Virtual Account
-   **Model bisnis:** Paket gratis dan berbayar serta komisi/biaya
    layanan transaksi

------------------------------------------------------------------------

# 1. Ringkasan Produk

## 1.1 Deskripsi

E-Ticket Event Platform adalah aplikasi pengelolaan event dan pemesanan
tiket. Organizer dapat membuat dan mengelola event, mengatur kategori
tiket, memantau peserta dan transaksi, mengundang anggota tim, serta
memantau kehadiran melalui QR Scanner.

Participant dapat menemukan event, mendaftar secara mandiri melalui
tautan publik, memilih tiket, mengisi data peserta, menyelesaikan
simulasi pembayaran, dan menerima e-ticket dengan QR Code unik.

Selain registrasi mandiri, Organizer atau Staff yang diberi izin dapat
membantu mendaftarkan peserta melalui dashboard. Pada tahap produk
akhir, kedua metode registrasi direncanakan menggunakan alur Order,
Payment, dan Ticket yang sama. Untuk tahap pengembangan saat ini, alur
tersebut hanya disimulasikan menggunakan data dummy di frontend.

Admin mengelola platform secara keseluruhan. Admin dapat memoderasi
event, mengelola akun, mengatur paket layanan, memantau transaksi dan
pendapatan platform, menangani keluhan, serta melihat audit log.

## 1.2 Visi Produk

Menyediakan platform ticketing yang mudah digunakan, aman, dan dapat
dikembangkan menjadi layanan komersial bagi berbagai penyelenggara
acara.

## 1.3 Tujuan Produk

1.  Mempermudah Organizer membuat, mengelola, dan memublikasikan event.
2.  Mempermudah Participant menemukan event dan mendapatkan tiket.
3.  Menyediakan dua metode registrasi: mandiri dan dibantu
    Organizer/Staff.
4.  Mengurangi penggunaan tiket palsu dan check-in ganda.
5.  Membantu Organizer mengelola peserta, transaksi, tim, dan kehadiran.
6.  Memberikan Admin alat untuk mengawasi operasional dan perkembangan
    bisnis platform.
7.  Menyiapkan monetisasi melalui paket layanan dan komisi/biaya
    layanan.

## 1.4 Prinsip Produk

-   Backend merupakan sumber kebenaran untuk role, permission, status
    pembayaran, kuota, tiket, dan check-in.
-   Tidak ada akses yang diberikan hanya dengan menyembunyikan atau
    menampilkan tombol pada frontend.
-   Organizer hanya dapat mengakses event yang dimilikinya atau event
    yang menugaskannya sebagai Staff.
-   Staff bukan role global. Staff adalah keanggotaan pengguna pada
    event tertentu.
-   Registrasi mandiri dan registrasi dibantu harus menggunakan proses
    transaksi yang sama.
-   Pembayaran MVP adalah simulasi Virtual Account, bukan transaksi bank
    sungguhan.
-   Semua tindakan administratif penting harus memiliki jejak audit.
-   Fitur yang belum masuk MVP harus tetap ditandai sebagai pengembangan
    lanjutan, bukan dianggap sudah tersedia.

## 1.5 Indikator Keberhasilan

MVP dinyatakan berhasil apabila:

-   Organizer dapat membuat event, mengatur tiket, dan mengajukan
    moderasi.
-   Admin dapat memeriksa dan memutuskan pengajuan event.
-   Event yang dipublikasikan memiliki URL publik.
-   Participant dapat mendaftar tanpa membuat akun.
-   Organizer/Staff yang memiliki izin dapat membantu registrasi
    peserta.
-   Kedua metode registrasi menghasilkan Order dan tiket dengan aturan
    yang sama.
-   Pembayaran simulasi dapat berhasil, gagal, atau kedaluwarsa.
-   Tiket hanya diterbitkan setelah pembayaran dikonfirmasi backend atau
    pesanan gratis berhasil.
-   QR Code unik dapat divalidasi.
-   Check-in online mencegah satu tiket digunakan lebih dari sekali.
-   Akses Staff dibatasi sesuai event dan permission.
-   Admin dapat memantau event, pengguna, transaksi, pendapatan, paket,
    dan keluhan sesuai cakupan tahap implementasi.

## 1.6 Fokus Pengembangan Saat Ini: UI/Frontend dengan Data Dummy

Fokus pengembangan dalam PRD ini tetap **tampilan dan interaksi frontend
Flutter menggunakan data dummy**. Audit workspace pada 2026-11-05
menemukan folder `backend/` berisi implementasi Node.js/Express dan
Supabase, serta kode Flutter yang memiliki API client/service. Keberadaan
artefak tersebut tidak mengubah ruang lingkup produk tahap ini: PRD tidak
mengarahkan AI Developer untuk mengembangkan backend, database, atau
integrasi API sebagai bagian dari pekerjaan UI prototype. Jangan
menganggap seluruh aplikasi berjalan offline/dummy saat ini; lihat audit
implementasi pada bagian 20.

Ketentuan tahap saat ini:

1.  Prioritaskan penyelesaian halaman, layout, navigasi, komponen UI,
    responsivitas, dan konsistensi desain untuk setiap role.
2.  Gunakan data dummy lokal yang terstruktur dan mudah diganti ketika
    backend tersedia.
3.  Interaksi seperti login, logout, tambah/edit/hapus data, pencarian,
    filter, perubahan status, registrasi, pembayaran, dan check-in boleh
    disimulasikan di sisi frontend. Tampilkan perubahan UI yang masuk
    akal, tetapi jangan menganggapnya sebagai transaksi sungguhan.
4.  Jangan membuat request HTTP, endpoint API, koneksi database, Prisma,
    atau konfigurasi server pada tahap ini.
5.  Jangan menambahkan ketergantungan pada backend agar aplikasi dapat
    dijalankan dan seluruh halaman dapat diuji.
6.  Pisahkan data dummy dari widget/komponen tampilan, misalnya melalui
    model, repository/mock service, atau sumber data lokal yang sesuai
    dengan struktur proyek. Hindari menulis data dummy berulang kali di
    dalam banyak widget.
7.  Siapkan struktur dan kontrak model frontend agar nantinya mudah
    dihubungkan ke API, tetapi jangan membangun backend lebih awal.
8.  Sediakan data contoh untuk setiap role dan kondisi UI penting,
    termasuk data kosong, loading, error, status berhasil, status gagal,
    dan status tanpa izin jika relevan. Kondisi tersebut dapat
    disimulasikan secara lokal.
9.  Pastikan perpindahan role untuk keperluan demo tidak dianggap sebagai
    autentikasi atau keamanan sesungguhnya.
10. Jangan menghapus kebutuhan backend, database, keamanan server, dan
    API yang dijelaskan pada bagian lain. Bagian-bagian tersebut adalah
    rancangan target untuk tahap integrasi berikutnya, bukan pekerjaan
    yang harus dikerjakan sekarang.

**Prioritas keputusan:** jika ada instruksi teknis di bagian lain PRD
yang seolah meminta implementasi backend sekarang, ketentuan pada bagian
ini yang berlaku untuk tahap pengembangan saat ini.

------------------------------------------------------------------------

# 2. Role, Identitas, dan Hak Akses

## 2.1 Tiga Role Global

Aplikasi hanya memiliki tiga role global:

  -----------------------------------------------------------------------
  Role                                Deskripsi
  ----------------------------------- -----------------------------------
  `PARTICIPANT`                       Pengguna yang mendaftar dan
                                      mengikuti event.

  `ORGANIZER`                         Pengguna yang membuat event atau
                                      menjadi anggota tim event.

  `ADMIN`                             Pengelola platform secara
                                      keseluruhan.
  -----------------------------------------------------------------------

Admin dibuat melalui proses administratif/seed yang aman. Form
registrasi umum tidak boleh memberikan role ADMIN.

## 2.2 Organizer, Owner, dan Staff

Organizer adalah role global untuk pengguna yang mengelola event. Di
dalam setiap event, pengguna Organizer memiliki salah satu jenis
keanggotaan:

-   `OWNER`: pemilik/pengelola utama event.
-   `STAFF`: anggota tim yang diundang Owner.

Owner dan Staff bukan role global baru. Keduanya dibedakan melalui
keanggotaan event (`EventMember`) dan permission.

Satu akun Organizer dapat: - Menjadi Owner pada Event A. - Menjadi Staff
pada Event B. - Tidak memiliki akses pada Event C.

Pada prototype frontend, tampilan dan aksi harus menyesuaikan `event_id`,
status keanggotaan, dan permission dari data dummy. Validasi keamanan
yang sesungguhnya tetap wajib diterapkan di backend pada tahap integrasi.

## 2.3 Permission Staff

Owner dapat memberikan izin Staff per event. Permission awal yang
disarankan:

  -----------------------------------------------------------------------
  Permission                          Fungsi
  ----------------------------------- -----------------------------------
  `VIEW_EVENT`                        Melihat detail event yang
                                      ditugaskan.

  `VIEW_PARTICIPANTS`                 Melihat data peserta event.

  `ASSIST_REGISTRATION`               Membantu membuat registrasi
                                      peserta.

  `VIEW_ORDERS`                       Melihat daftar pesanan sesuai batas
                                      data yang diizinkan.

  `SCAN_TICKET`                       Membuka fitur scanner.

  `CHECK_IN_TICKET`                   Melakukan check-in tiket.

  `VIEW_SCAN_HISTORY`                 Melihat riwayat pemindaian.

  `VIEW_REPORTS`                      Melihat laporan event.

  `EXPORT_PARTICIPANTS`               Mengunduh data peserta.
  -----------------------------------------------------------------------

Aturan: - Owner memiliki seluruh izin pengelolaan event. - Staff hanya
memperoleh permission yang diberikan Owner. - Secara default Staff tidak
boleh mengubah detail utama event, harga, kuota, pengaturan penjualan,
anggota tim, atau status pembayaran. - Owner dapat mencabut akses Staff
kapan saja. - Pencabutan akses berlaku untuk permintaan berikutnya dan
harus diperiksa oleh backend. - Staff tidak boleh mengakses event lain
dengan mengganti ID pada URL atau request API.

## 2.4 Matriks Hak Akses Global

  -----------------------------------------------------------------------------------
  Fitur                     Participant      Organizer      Organizer           Admin
                                                 Owner          Staff 
  ---------------------- -------------- -------------- -------------- ---------------
  Melihat event publik               Ya             Ya             Ya              Ya

  Membuat event                   Tidak             Ya          Tidak           Tidak

  Mengubah event                  Tidak             Ya          Tidak        Tindakan
                                                                        administratif
                                                                             terbatas

  Mengatur                        Tidak             Ya          Tidak           Tidak
  kategori/harga/kuota                                                

  Mengajukan moderasi             Tidak             Ya          Tidak           Tidak

  Menyetujui/menolak              Tidak          Tidak          Tidak              Ya
  event                                                               

  Registrasi mandiri                 Ya  Tidak sebagai  Tidak sebagai           Tidak
                                               peserta        peserta 
                                               melalui        melalui 
                                             dashboard      dashboard 
                                             Organizer          Staff 

  Registrasi dibantu              Tidak             Ya    Jika diberi           Tidak
                                                                 izin 

  Melihat peserta         Data miliknya Ya untuk event    Jika diberi          Sesuai
                                              miliknya           izin       kebutuhan
                                                                        administratif

  Mengelola Staff                 Tidak             Ya          Tidak   Tidak sebagai
                                                                        pengelola tim
                                                                                event

  Scanner/check-in                Tidak           Jika    Jika diberi   Tidak sebagai
                                        diperlukan dan           izin   petugas event
                                             diizinkan                
                                                sistem                

  Melihat laporan event           Tidak             Ya    Jika diberi       Ringkasan
                                                                 izin    platform dan
                                                                               detail
                                                                        administratif

  Mengelola paket                 Tidak          Tidak          Tidak              Ya

  Mengelola langganan             Tidak             Ya          Tidak Mengawasi semua
  sendiri                                                             

  Memantau pendapatan             Tidak          Tidak          Tidak              Ya
  platform                                                            

  Mengirim keluhan                   Ya             Ya  Jika tersedia           Tidak
                                                           untuk akun 

  Menangani keluhan               Tidak          Tidak          Tidak              Ya

  Mengelola akun                  Tidak          Tidak          Tidak              Ya
  platform                                                            

  Mengatur konfigurasi            Tidak          Tidak          Tidak              Ya
  platform                                                            

  Melihat audit log               Tidak  Riwayat event  Riwayat event              Ya
  platform                                sesuai fitur    sesuai izin 
  -----------------------------------------------------------------------------------

------------------------------------------------------------------------

# 3. Struktur Navigasi dan Halaman Aplikasi

Aplikasi memiliki area publik dan area setelah login. Navigasi dan
halaman yang terlihat harus menyesuaikan role serta permission.

## 3.1 Area Publik (Tanpa Login)

Halaman publik dapat dibuka oleh siapa pun melalui browser.

### 3.1.1 Beranda

Tujuan: memperkenalkan platform dan menampilkan event yang tersedia.

Komponen: - Header/logo platform. - Navigasi Beranda, Event, Bantuan,
Login, dan Daftar sebagai Organizer. - Banner atau event pilihan jika
tersedia. - Daftar event terbaru/populer. - Kolom pencarian. - Filter
kategori dan tanggal. - Footer berisi kontak, kebijakan privasi, dan
ketentuan layanan.

Aksi: - Membuka daftar event. - Membuka detail event. - Membuka halaman
login/registrasi Organizer. - Membuka halaman bantuan.

### 3.1.2 Daftar Event

Komponen: - Kartu event berisi poster, nama, tanggal, lokasi/jenis
event. - Pencarian berdasarkan nama event. - Filter kategori, tanggal,
dan tipe event. - Pagination atau infinite scroll.

Aturan: - Hanya event yang berstatus publik dan memenuhi jadwal
publikasi yang ditampilkan. - Event draft, menunggu moderasi, ditolak,
atau ditangguhkan tidak boleh muncul sebagai event yang dapat dipesan.

### 3.1.3 Detail Event Publik

Komponen: - Poster/banner. - Nama event dan deskripsi. -
Penyelenggara. - Tanggal dan waktu beserta zona waktu. - Lokasi atau
tautan event online. - Tipe event: offline, online, atau hybrid. -
Kategori tiket, harga, periode penjualan, dan ketersediaan kuota. -
Informasi kontak/bantuan. - Tombol Daftar/Beli Tiket.

Aksi: - Memilih kategori tiket. - Melanjutkan ke formulir registrasi. -
Membagikan URL event.

### 3.1.4 Formulir Registrasi Mandiri

Tujuan: memungkinkan calon peserta mendaftar tanpa akun.

Komponen: - Ringkasan event. - Pilihan kategori tiket dan jumlah. - Form
data setiap peserta/tiket: nama dan email, serta nomor telepon jika
diperlukan. - Email kontak pemesan. - Ringkasan harga, biaya layanan
jika berlaku, dan total. - Persetujuan ketentuan. - Tombol Buat Pesanan.

Aturan: - Peserta tidak wajib login. - Data setiap tiket harus terhubung
dengan satu identitas peserta (`Attendee`). - Backend memvalidasi
periode penjualan, kuota, batas jumlah tiket, dan harga. - Harga yang
digunakan pada OrderItem harus disimpan sebagai snapshot agar perubahan
harga berikutnya tidak mengubah pesanan lama.

### 3.1.5 Konfirmasi Pesanan

Komponen: - Nomor Order. - Detail event dan tiket. - Jumlah tiket. -
Ringkasan nominal. - Status pesanan. - Tombol menuju pembayaran.

### 3.1.6 Pembayaran Simulasi

Komponen: - Nomor referensi pesanan. - Nomor Virtual Account simulasi. -
Nama penerima simulasi. - Jumlah pembayaran. - Batas waktu pembayaran. -
Status pembayaran. - Tombol simulasi berhasil/gagal hanya pada
lingkungan pengujian yang diizinkan.

Aturan keamanan: - Frontend tidak boleh mengubah status pembayaran
secara langsung. - Aksi simulasi mengirim permintaan ke backend. -
Backend memvalidasi status dan batas waktu, lalu mengubah status. -
Simulasi harus diberi penanda yang jelas dan tidak boleh diklaim sebagai
pembayaran bank sungguhan.

### 3.1.7 Halaman E-Ticket

Komponen: - Nama event. - Nama pemegang tiket. - Kategori tiket. - Nomor
tiket. - QR Code unik. - Status tiket. - Jadwal dan lokasi event. -
Petunjuk penggunaan tiket. - Tautan bantuan. - Unduh/cetak PDF dapat
menjadi fitur lanjutan.

Aturan: - QR Code hanya memuat token/URL validasi yang aman, bukan data
pribadi lengkap. - Tiket hanya dapat dibuka melalui akun pemilik atau
tautan akses bertoken yang aman. - QR setiap tiket harus berbeda.

### 3.1.8 Bantuan dan Buat Laporan

Komponen: - Kontak resmi platform. - Kategori masalah. - Email kontak. -
Nomor Order jika ada. - Subjek dan deskripsi. - Lampiran bukti jika
diimplementasikan. - Tombol Kirim Laporan.

Setelah dikirim, sistem menampilkan nomor laporan dan mekanisme aman
untuk memeriksa status.

### 3.1.9 Periksa Status Laporan

Komponen: - Nomor laporan. - Status terkini. - Riwayat status yang boleh
dilihat pelapor. - Balasan Admin yang ditujukan kepada pelapor.

Akses menggunakan token acak/tautan aman. Nomor laporan saja tidak cukup
untuk membuka isi laporan.

------------------------------------------------------------------------

# 4. Halaman Participant

Participant dapat menggunakan fitur publik tanpa login. Jika membuat
akun, Participant memperoleh halaman akun untuk mengelola riwayat
pesanan.

## 4.1 Navigasi Participant

``` text
Area Participant
├── Beranda
├── Event
├── Tiket Saya
│   ├── Daftar Tiket
│   └── Detail E-Ticket
├── Riwayat Pesanan
│   └── Detail Pesanan
├── Profil
└── Bantuan
    ├── Buat Laporan
    └── Status Laporan
```

Halaman Beranda, Event, Detail Event, Registrasi, dan Pembayaran tetap
merupakan halaman publik. Menu akun hanya tampil setelah Participant
login.

## 4.2 Dashboard Participant

Komponen: - Sapaan pengguna. - Ringkasan tiket aktif. - Event yang akan
datang berdasarkan tiket pengguna. - Pesanan yang menunggu pembayaran. -
Akses cepat ke Tiket Saya dan Riwayat Pesanan.

Fitur: - Membuka tiket aktif. - Melanjutkan pembayaran pesanan yang
masih berlaku. - Melihat riwayat pesanan.

## 4.3 Tiket Saya

Komponen: - Daftar e-ticket milik akun. - Nama event. - Tanggal event. -
Kategori tiket. - Status tiket. - Filter tiket aktif, sudah digunakan,
atau dibatalkan.

Fitur: - Membuka detail e-ticket. - Menampilkan QR Code. - Membuka
informasi event.

## 4.4 Riwayat Pesanan

Komponen: - Nomor Order. - Tanggal pemesanan. - Event. - Jumlah tiket. -
Total pembayaran. - Status Order dan Payment.

Fitur: - Melihat detail pesanan. - Membuka tiket yang sudah
diterbitkan. - Mengakses bantuan terkait pesanan.

## 4.5 Profil Participant

Komponen: - Nama. - Email. - Nomor telepon jika digunakan. - Pengaturan
akun. - Ubah kata sandi. - Logout.

Batasan: - Participant tidak dapat mengubah data transaksi yang telah
dikonfirmasi. - Participant tidak dapat melihat data peserta lain. -
Participant tidak dapat mengakses dashboard Organizer atau Admin.

------------------------------------------------------------------------

# 5. Halaman Organizer

Organizer menggunakan dashboard berbasis web/desktop sebagai area utama
pengelolaan event. Tampilan harus responsif agar halaman penting tetap
dapat digunakan pada layar mobile.

## 5.1 Skema Tampilan Organizer

Gunakan layout dashboard dengan sidebar kiri, topbar, dan area konten
utama.

``` text
┌──────────────────────────────────────────────────────────────────┐
│ LOGO PLATFORM                 Event aktif ▼    Notifikasi  Profil │
├───────────────────┬──────────────────────────────────────────────┤
│ SIDEBAR           │ KONTEN UTAMA                                 │
│                   │                                              │
│ Dashboard         │ Judul halaman                                │
│ Event Saya        │ Deskripsi singkat / breadcrumb               │
│   - Semua Event   │                                              │
│   - Buat Event    │ Kartu statistik / filter / tombol aksi       │
│ Peserta           │                                              │
│ Registrasi Manual │ Tabel / grafik / formulir                    │
│ Tim Event         │                                              │
│ Scanner           │                                              │
│ Laporan           │                                              │
│ Paket Saya        │                                              │
│ Pengaturan        │                                              │
│ Bantuan           │                                              │
│                   │                                              │
│ Keluar            │                                              │
└───────────────────┴──────────────────────────────────────────────┘
```

### Navigasi Organizer Owner

``` text
Dashboard
Event Saya
├── Semua Event
├── Buat Event
└── Detail Event
    ├── Ringkasan
    ├── Informasi Event
    ├── Kategori Tiket
    ├── Peserta & Pesanan
    ├── Registrasi Manual
    ├── Tim Event
    ├── Scanner & Check-in
    ├── Laporan
    └── Riwayat Aktivitas
Paket & Langganan
Transaksi Paket
Profil Organizer
Bantuan
Logout
```

Menu yang berhubungan dengan event hanya dapat diakses untuk event yang
dimiliki Owner.

## 5.2 Dashboard Organizer Owner

Tujuan: memberi ringkasan kondisi seluruh event milik Organizer.

Komponen: - Total event. - Event draft. - Event menunggu moderasi. -
Event dipublikasikan/aktif. - Tiket terjual. - Pesanan menunggu
pembayaran. - Total peserta. - Total check-in. - Ringkasan penjualan
kotor. - Daftar event terbaru. - Notifikasi revisi atau keputusan
moderasi.

Fitur: - Memilih event untuk melihat detail. - Membuat event baru. -
Melihat event yang membutuhkan tindakan. - Membuka laporan event.

Batasan: - Dashboard hanya menampilkan data event yang dimiliki atau
diakses Organizer. - Dashboard tidak menampilkan pendapatan keseluruhan
platform.

## 5.3 Halaman Event Saya

Komponen: - Tabel/kartu seluruh event milik Owner. - Nama event. -
Tanggal pelaksanaan. - Status event. - Jumlah tiket terjual. - Jumlah
peserta. - Status moderasi. - Tombol aksi.

Filter: - Semua. - Draft. - Menunggu moderasi. - Perlu revisi. -
Disetujui/dipublikasikan. - Selesai. - Ditolak. -
Ditangguhkan/dibatalkan.

Aksi: - Membuka detail event. - Mengedit event jika status
mengizinkan. - Mengajukan moderasi. - Membuka URL publik untuk event
yang sudah dipublikasikan. - Menyalin tautan publik. - Melihat QR
registrasi publik.

## 5.4 Halaman Buat/Edit Event

Form dibagi ke beberapa bagian agar mudah digunakan.

### A. Informasi Dasar

-   Nama event.
-   Kategori event.
-   Deskripsi.
-   Poster/banner.
-   Nama penyelenggara yang ditampilkan.
-   Kontak penyelenggara.

### B. Jadwal

-   Tanggal dan waktu mulai.
-   Tanggal dan waktu selesai.
-   Zona waktu.

### C. Lokasi dan Format

-   Offline, online, atau hybrid.
-   Alamat lokasi untuk event offline.
-   Tautan online untuk event online.
-   Informasi tambahan lokasi.

### D. Kategori Tiket

-   Nama kategori tiket.
-   Deskripsi.
-   Harga.
-   Kuota.
-   Periode penjualan.
-   Status aktif.
-   Batas pembelian per Order.

### E. Pengaturan Registrasi

-   Informasi peserta yang wajib diisi.
-   Batas waktu pembayaran mengikuti kebijakan platform.
-   Pengaturan kuota.
-   Informasi yang tampil pada halaman publik.

Aksi: - Simpan sebagai draft. - Pratinjau halaman publik. - Ajukan
moderasi.

Aturan: - Event baru berstatus DRAFT. - Event yang diajukan berubah
menjadi PENDING_REVIEW. - Perubahan penting pada event yang sudah
dipublikasikan dapat memerlukan moderasi ulang sesuai kebijakan. - Owner
tidak dapat mengubah status moderasi secara manual.

## 5.5 Halaman Detail Event

Halaman detail event menggunakan tab atau subnavigation:

``` text
[Ringkasan] [Informasi] [Tiket] [Peserta] [Registrasi Manual]
[Tim] [Scanner] [Laporan] [Aktivitas]
```

Setiap tab dijelaskan di bawah.

### 5.5.1 Tab Ringkasan

Komponen: - Status event. - Jadwal dan lokasi. - Tiket terjual. -
Pesanan pending. - Peserta terdaftar. - Check-in berhasil. - Grafik
penjualan dan check-in sederhana. - URL publik dan QR registrasi.

Fitur: - Menyalin tautan. - Melihat halaman publik. - Membuka laporan
event.

### 5.5.2 Tab Informasi Event

Fitur: - Melihat informasi event. - Mengedit informasi jika status event
mengizinkan. - Melihat catatan revisi Admin. - Mengajukan ulang setelah
revisi.

### 5.5.3 Tab Kategori Tiket

Fitur: - Membuat kategori tiket. - Mengubah nama dan deskripsi. -
Mengatur harga. - Mengatur kuota. - Mengatur periode penjualan. -
Mengaktifkan/menonaktifkan kategori. - Melihat tiket terjual dan sisa
kuota.

Batasan: - Tidak boleh mengubah harga pesanan yang sudah dibuat. -
Perubahan kuota tidak boleh membuat jumlah terjual + jumlah yang sedang
ditahan melebihi batas baru. - Perubahan kategori yang sudah memiliki
transaksi harus mempertahankan riwayat transaksi.

### 5.5.4 Tab Peserta & Pesanan

Komponen: - Daftar peserta. - Nama peserta. - Email peserta. - Kategori
tiket. - Nomor Order. - Status pembayaran. - Status tiket. - Status
check-in. - Metode registrasi: SELF_SERVICE atau ASSISTED.

Fitur: - Pencarian nama/email/nomor Order. - Filter kategori tiket. -
Filter status pembayaran. - Filter status check-in. - Melihat detail
peserta dan pesanan. - Ekspor CSV jika permission/paket mengizinkan.

Batasan: - Organizer tidak boleh mengubah pembayaran menjadi PAID secara
manual. - Organizer tidak boleh melihat data event Organizer lain. -
Data sensitif hanya ditampilkan sesuai kebutuhan operasional.

### 5.5.5 Tab Registrasi Manual

Tujuan: Owner membantu calon peserta yang tidak mendaftar sendiri.

Komponen: - Form nama pemesan/kontak. - Email kontak. - Pilihan kategori
tiket. - Jumlah tiket. - Form data untuk setiap peserta. - Ringkasan
biaya. - Tombol Buat Pesanan.

Alur: 1. Owner membuka Registrasi Manual. 2. Memilih kategori dan jumlah
tiket. 3. Mengisi data setiap peserta. 4. Backend memvalidasi kuota dan
harga. 5. Backend membuat Order dengan `registration_method = ASSISTED`.
6. `assisted_by_member_id` diisi dengan keanggotaan Owner. 7. Sistem
membuat instruksi pembayaran yang sama seperti registrasi mandiri. 8.
Setelah pembayaran berhasil atau pesanan gratis dinyatakan berhasil,
tiket diterbitkan.

Batasan: - Owner tidak boleh melewati proses pembayaran untuk event
berbayar. - Owner tidak boleh mengubah status pembayaran secara
manual. - Registrasi manual tetap mengikuti kuota dan periode
penjualan. - Semua aktivitas dicatat dengan identitas pelaku.

### 5.5.6 Tab Tim Event

Komponen: - Daftar Owner dan Staff. - Nama dan email Staff. - Status
undangan. - Permission yang diberikan. - Waktu bergabung. - Tombol
Undang Staff. - Tombol Atur Permission. - Tombol Cabut Akses.

Alur undangan: 1. Owner memasukkan email Staff. 2. Sistem membuat
undangan bertoken aman dan masa berlaku. 3. Staff membuka tautan
undangan. 4. Staff login atau membuat akun Organizer. 5. Staff menerima
undangan. 6. Sistem membuat EventMember dengan membership_role STAFF. 7.
Owner mengatur permission.

Batasan: - Staff tidak dapat mengundang Staff lain. - Staff tidak dapat
mengubah Owner. - Owner tidak dapat mengundang akun dengan status
diblokir. - Pencabutan akses harus langsung berlaku pada backend.

### 5.5.7 Tab Scanner & Check-in

Komponen: - Pemilih event (jika Owner memiliki beberapa event). -
Tampilan kamera scanner. - Indikator online/offline. - Hasil
pemindaian. - Total check-in. - Tombol sinkronisasi jika ada antrean
offline.

Hasil pemindaian: - Valid dan check-in berhasil. - Tiket sudah
digunakan. - Tiket tidak ditemukan/tidak valid. - Tiket bukan untuk
event ini. - Tiket dibatalkan/dicabut. - Gagal memvalidasi karena
jaringan.

Batasan: - Owner hanya dapat melakukan scan/check-in pada event
miliknya. - Pemeriksaan token dan status tiket dilakukan backend saat
online. - Check-in harus atomik. - Mode offline terbatas dan harus
menampilkan bahwa hasil lokal belum terverifikasi server.

### 5.5.8 Tab Laporan Event

Komponen: - Total Order. - Total tiket terjual. - Total nilai penjualan
kotor. - Biaya layanan/komisi yang dibebankan pada event jika
tersedia. - Pesanan pending/expired/paid. - Jumlah peserta check-in. -
Grafik penjualan berdasarkan waktu. - Grafik check-in.

Fitur: - Filter tanggal. - Filter kategori tiket. - Ekspor laporan
sesuai paket dan permission.

Batasan: - Laporan Organizer bukan laporan pendapatan platform. -
Organizer tidak dapat melihat transaksi Organizer lain.

### 5.5.9 Tab Riwayat Aktivitas

Menampilkan tindakan penting pada event, misalnya: - Event
dibuat/diubah. - Event diajukan untuk moderasi. - Kategori tiket
diubah. - Staff diundang/dicabut. - Registrasi manual dibuat. - Check-in
dilakukan. - Pengaturan event diubah.

Informasi minimal: - Pelaku. - Jenis tindakan. - Waktu. - Event
terkait. - Ringkasan perubahan.

## 5.6 Halaman Organizer Staff

Staff menggunakan dashboard lebih sederhana daripada Owner. Staff tidak
melihat menu pengelolaan bisnis atau pengaturan event.

### Navigasi Staff

``` text
Dashboard Staff
Event yang Ditugaskan
├── Ringkasan Event
├── Peserta (jika VIEW_PARTICIPANTS)
├── Registrasi Manual (jika ASSIST_REGISTRATION)
├── Scanner (jika SCAN_TICKET/CHECK_IN_TICKET)
├── Riwayat Scan (jika VIEW_SCAN_HISTORY)
└── Laporan (jika VIEW_REPORTS)
Profil
Bantuan
Logout
```

### Dashboard Staff

Komponen: - Daftar event yang ditugaskan. - Jadwal event. - Status
event. - Ringkasan tugas/permission. - Tombol menuju fitur yang
diizinkan.

### Event yang Ditugaskan

Fitur: - Melihat hanya event yang keanggotaannya ACTIVE. - Membuka
ringkasan event. - Membuka scanner jika memiliki permission. - Membuka
data peserta jika memiliki permission.

### Registrasi Manual Staff

Hanya tampil jika Staff memiliki `ASSIST_REGISTRATION`.

Fitur: - Mengisi data peserta. - Memilih kategori dan jumlah tiket. -
Membuat pesanan assisted. - Melihat hasil pembuatan Order.

Batasan: - Tidak dapat mengubah harga atau kuota. - Tidak dapat
menyatakan pembayaran berhasil. - Tidak dapat mengubah pengaturan
event. - `assisted_by_member_id` mencatat Staff yang melakukan
registrasi.

### Scanner Staff

Hanya tampil jika Staff memiliki permission scanner/check-in.

Fitur: - Memindai QR. - Melihat hasil validasi. - Melakukan check-in
jika memiliki `CHECK_IN_TICKET`. - Melihat riwayat scan jika memiliki
`VIEW_SCAN_HISTORY`. - Melihat status sinkronisasi offline.

### Batasan Staff

Staff tidak boleh: - Membuat event. - Mengedit informasi utama event. -
Membuat/mengubah kategori tiket. - Mengubah harga dan kuota. - Mengelola
langganan. - Mengundang atau mencabut Staff lain. - Mengakses event yang
tidak ditugaskan. - Mengakses dashboard Admin. - Mengubah status
pembayaran. - Melihat laporan jika tidak memiliki permission.

Jika permission tidak tersedia, menu dan endpoint terkait harus ditolak.
Menyembunyikan menu saja tidak cukup.

------------------------------------------------------------------------

# 6. Halaman Admin Platform

Admin memiliki dashboard khusus tingkat platform. Tampilan Admin
menggunakan sidebar kiri, topbar, dan konten utama. Admin tidak
menggunakan dashboard Organizer.

## 6.1 Skema Tampilan Admin

``` text
┌────────────────────────────────────────────────────────────────────┐
│ LOGO ADMIN             Pencarian   Notifikasi       Profil Admin   │
├───────────────────────┬────────────────────────────────────────────┤
│ SIDEBAR ADMIN         │ KONTEN UTAMA                               │
│                       │                                            │
│ Dashboard Bisnis      │ Judul halaman                              │
│ Manajemen Event       │ Filter periode / aksi utama                │
│ Manajemen Pengguna    │                                            │
│ Paket Layanan         │ Kartu statistik                            │
│ Langganan             │ Grafik / tabel / detail                    │
│ Transaksi & Pendapatan│                                            │
│ Keluhan & Support     │                                            │
│ Laporan & Analitik    │                                            │
│ Pengaturan Platform   │                                            │
│ Audit Log             │                                            │
│                       │                                            │
│ Keluar                │                                            │
└───────────────────────┴────────────────────────────────────────────┘
```

Navigasi Admin:

``` text
Dashboard Bisnis
Manajemen Event
├── Semua Event
├── Menunggu Moderasi
└── Detail Event
Manajemen Pengguna
├── Organizer
└── Participant
Paket Layanan
├── Daftar Paket
└── Buat/Edit Paket
Langganan
Transaksi & Pendapatan
Keluhan & Support
├── Semua Laporan
└── Detail Laporan
Laporan & Analitik
Pengaturan Platform
Audit Log
Profil Admin
Logout
```

Satu role ADMIN memiliki seluruh kewenangan Admin untuk MVP. Pemisahan
Admin Finance, Moderation, atau Support dapat dipertimbangkan setelah
kebutuhan operasional meningkat.

## 6.2 Dashboard Bisnis Admin

Tujuan: memantau jalannya bisnis dan operasional platform dari satu
halaman.

### Kartu statistik utama

-   Total event.
-   Event aktif.
-   Event mendatang.
-   Event selesai.
-   Event menunggu moderasi.
-   Total Organizer.
-   Total akun Participant.
-   Total tiket diterbitkan/terjual.
-   Total Order.
-   Total transaksi berhasil.
-   Total pendapatan platform.
-   Keluhan yang belum selesai.

Definisi: - Event aktif: event sudah dipublikasikan dan waktu saat ini
berada di antara waktu mulai dan selesai. - Event mendatang: event sudah
dipublikasikan tetapi belum dimulai. - Event selesai: event sudah
melewati waktu selesai. - Event menunggu moderasi: event berada pada
status PENDING_REVIEW. - Pendapatan platform berbeda dari total
penjualan tiket.

### Grafik

-   Pertumbuhan event per periode.
-   Pertumbuhan Organizer dan Participant.
-   Penjualan tiket per periode.
-   Pendapatan platform per periode.
-   Distribusi status event.
-   Distribusi kategori event.
-   Penggunaan paket layanan.

### Daftar aktivitas dan perhatian

-   Event baru menunggu moderasi.
-   Event yang membutuhkan tindakan.
-   Keluhan prioritas tinggi.
-   Transaksi bermasalah.
-   Perubahan penting pada platform.

Filter dashboard: - Hari ini. - 7 hari. - 30 hari. - Bulan ini. -
Rentang tanggal khusus.

## 6.3 Manajemen Event

Halaman daftar: - Semua event pada platform. - Nama event. - Organizer
pemilik. - Kategori. - Jadwal. - Status publikasi/moderasi. - Jumlah
tiket terjual. - Filter dan pencarian.

Halaman detail: - Informasi event. - Data Organizer. - Kategori dan
harga tiket. - Statistik peserta dan transaksi. - Riwayat moderasi. -
Riwayat tindakan administratif.

Aksi Admin: - Menyetujui event. - Menolak event dengan alasan. - Meminta
revisi dengan catatan. - Menangguhkan event dengan alasan. - Membuka
kembali event yang ditangguhkan jika sesuai kebijakan.

Aturan: - Setiap keputusan moderasi menyimpan Admin, waktu, keputusan,
dan alasan. - Admin tidak mengubah data event diam-diam. - Jika Admin
melakukan koreksi administratif, perubahan harus masuk AuditLog. - Event
yang belum disetujui tidak dapat dipesan publik.

## 6.4 Manajemen Pengguna

### Tab Organizer

Informasi: - Nama dan email. - Nama organisasi. - Tanggal bergabung. -
Jumlah event. - Paket aktif. - Status langganan. - Status akun.

Aksi: - Melihat profil Organizer. - Melihat daftar event Organizer. -
Melihat paket/langganan. - Mengaktifkan/menonaktifkan akun sesuai
kebijakan. - Melihat riwayat tindakan yang relevan.

### Tab Participant

Informasi: - Nama dan email jika memiliki akun. - Tanggal bergabung. -
Jumlah pesanan/tiket. - Status akun.

Aksi: - Melihat profil. - Melihat riwayat pesanan sesuai kebutuhan
administratif. - Mengaktifkan/menonaktifkan akun sesuai kebijakan.

Batasan: - Admin tidak dapat melihat password atau credential rahasia. -
Tindakan pembatasan akun harus menyimpan alasan dan AuditLog. - Akun
tanpa indikasi pelanggaran tidak boleh dinonaktifkan tanpa alasan yang
tercatat.

## 6.5 Paket Layanan

Admin dapat mengelola paket gratis dan berbayar.

Contoh paket awal (nama dan harga hanya ilustrasi, belum menjadi
keputusan harga final): - Basic. - Pro. - Enterprise.

Informasi paket: - Nama. - Deskripsi. - Harga. - Durasi. - Status
aktif/nonaktif. - Daftar fitur. - Batas penggunaan.

Contoh fitur: - Maksimum event. - Maksimum kategori tiket per event. -
Maksimum Staff per event. - Akses laporan lanjutan. - Ekspor peserta. -
Analitik.

Fitur halaman: - Melihat daftar paket. - Membuat paket. - Mengedit
paket. - Mengaktifkan/menonaktifkan paket. - Mengarsipkan paket. -
Mengatur nilai batas fitur. - Melihat Organizer yang menggunakan paket.

Aturan: - Paket gratis tetap direpresentasikan sebagai Plan. - Perubahan
paket tidak boleh mengubah transaksi historis. - Paket yang sedang
digunakan tidak boleh dihapus permanen; gunakan nonaktif/arsip. - Sistem
harus memeriksa batas paket di backend ketika Organizer menggunakan
fitur terbatas.

## 6.6 Langganan Organizer

Komponen: - Organizer. - Paket aktif. - Tanggal mulai. - Tanggal
berakhir. - Status. - Riwayat perubahan paket. - Riwayat pembayaran
paket.

Fitur: - Melihat semua langganan. - Memfilter berdasarkan
paket/status. - Melihat riwayat langganan. - Melihat pembayaran paket. -
Melakukan tindakan administratif sesuai kebijakan.

Status langganan yang disarankan: - `ACTIVE` - `PENDING_PAYMENT` -
`EXPIRED` - `CANCELLED` - `SUSPENDED`

## 6.7 Transaksi & Pendapatan

Halaman ini khusus Admin untuk memantau keuangan platform.

Tab: - Transaksi tiket. - Pembayaran paket. - Pendapatan platform.

Informasi transaksi: - Referensi transaksi. - Jenis transaksi. - Order
atau Subscription terkait. - Organizer. - Nilai bruto. - Biaya/komisi
platform. - Status. - Waktu.

Dashboard pendapatan membedakan: - Gross ticket sales: total nilai
penjualan tiket. - Platform revenue: bagian yang menjadi pendapatan
platform. - Subscription revenue: pendapatan dari paket berbayar.

Contoh ilustrasi: - Penjualan tiket: Rp10.000.000. - Komisi platform 5%:
Rp500.000. - Pembayaran paket: Rp100.000. - Total pendapatan platform:
Rp600.000.

Nilai di atas hanya contoh, bukan penetapan tarif.

Aturan: - Nilai komisi/biaya yang berlaku pada transaksi harus disimpan
sebagai snapshot. - Perubahan konfigurasi biaya tidak boleh menghitung
ulang transaksi lama. - Pencatatan transaksi harus dapat ditelusuri ke
Order atau Subscription. - Integrasi pencairan dana/payout bukan fitur
MVP kecuali disepakati terpisah.

## 6.8 Keluhan & Support Center

Daftar keluhan: - Nomor laporan. - Pelapor. - Kategori. - Subjek. -
Tanggal. - Prioritas. - Status. - Admin penanggung jawab.

Kategori: - REGISTRATION - PAYMENT - E_TICKET - SCANNER - EVENT -
ACCOUNT - SUBSCRIPTION - TRANSACTION - OTHER

Status: - OPEN - IN_PROGRESS - WAITING_FOR_USER - RESOLVED - CLOSED

Fitur: - Mencari dan memfilter laporan. - Membuka detail laporan. -
Menetapkan prioritas. - Menugaskan penanganan kepada Admin (untuk MVP
dapat berupa Admin yang sedang login). - Membalas pelapor. - Menambahkan
catatan internal. - Mengubah status. - Melihat riwayat aktivitas. -
Menutup laporan setelah selesai.

Batasan: - Catatan internal tidak boleh terlihat oleh pelapor. - Pelapor
hanya dapat melihat balasan publik dan status yang relevan. - Akses
laporan publik wajib menggunakan token aman.

## 6.9 Laporan & Analitik

Laporan: - Pertumbuhan event. - Pertumbuhan pengguna. - Penjualan
tiket. - Pendapatan platform. - Penggunaan paket. - Status transaksi. -
Kategori event. - Keluhan dan waktu penyelesaian.

Fitur: - Filter periode. - Filter kategori/status jika relevan. -
Tampilan grafik dan tabel. - Ekspor laporan dapat menjadi fitur
lanjutan.

## 6.10 Pengaturan Platform

Admin dapat mengelola: - Nama dan identitas platform. - Kontak resmi. -
Persentase komisi. - Biaya tetap jika digunakan. - Aturan biaya
layanan. - Batas waktu pembayaran default. - Ketentuan layanan. -
Kebijakan privasi. - Kebijakan pembatalan/refund ketika sudah
ditentukan. - Konfigurasi umum.

Aturan: - Perubahan konfigurasi penting harus masuk riwayat pengaturan
dan AuditLog. - Perubahan komisi tidak berlaku surut. - Secret/API key
tidak boleh ditampilkan dalam halaman pengaturan umum.

## 6.11 Audit Log

Informasi: - Aktor. - Role. - Aksi. - Entitas yang diubah. - ID
entitas. - Waktu. - Ringkasan nilai sebelum/sesudah jika aman
disimpan. - IP/device metadata jika diperlukan.

Aksi yang wajib dicatat: - Login administratif penting. - Moderasi
event. - Penangguhan event. - Penonaktifan akun. - Perubahan paket. -
Perubahan harga paket. - Perubahan komisi/biaya. - Perubahan status
keluhan. - Perubahan langganan secara administratif.

Audit log bersifat append-only dari sisi aplikasi. Pengguna biasa tidak
boleh mengedit atau menghapus catatan audit.

------------------------------------------------------------------------

# 7. Model Bisnis dan Aturan Monetisasi

## 7.1 Sumber Pendapatan

Platform memiliki dua jalur pendapatan:

1.  Paket layanan Organizer: tersedia paket gratis dan paket berbayar.
2.  Komisi/biaya layanan: biaya yang dihitung dari transaksi tiket
    sesuai konfigurasi platform.

Detail tarif, pihak yang menanggung biaya, dan mekanisme penagihan masih
harus ditetapkan sebelum peluncuran komersial.

## 7.2 Paket Layanan

Plan dan PlanFeature digunakan untuk mengatur batas fitur. Backend wajib
memeriksa batas tersebut.

Contoh feature code: - `MAX_EVENTS` - `MAX_STAFF_PER_EVENT` -
`MAX_TICKET_TYPES` - `PARTICIPANT_EXPORT` - `ADVANCED_REPORTS` -
`ANALYTICS`

## 7.3 Pemisahan Nilai Keuangan

Jangan menyamakan: - Nilai bruto penjualan tiket. - Biaya layanan yang
dibebankan kepada peserta/Organizer. - Komisi yang menjadi hak
platform. - Pendapatan paket. - Dana yang menjadi hak Organizer.

Setiap jenis nilai harus diberi nama dan definisi yang jelas di
database, API, dan UI.

------------------------------------------------------------------------

# 8. Alur Bisnis Utama

## 8.1 Pembuatan dan Moderasi Event

1.  Organizer login.
2.  Organizer membuat event.
3.  Organizer mengatur kategori tiket dan kuota.
4.  Event disimpan sebagai DRAFT.
5.  Organizer mengajukan event.
6.  Event menjadi PENDING_REVIEW.
7.  Admin meninjau event.
8.  Admin menyetujui, menolak, atau meminta revisi.
9.  Jika disetujui dan dipublikasikan, URL publik tersedia.
10. Organizer membagikan URL/QR registrasi.

## 8.2 Registrasi Mandiri

1.  Participant membuka URL event.
2.  Participant memilih tiket.
3.  Participant mengisi data pemesan dan setiap peserta.
4.  Backend memeriksa kuota, periode penjualan, dan batas pembelian.
5.  Backend membuat Order, OrderItem, Attendee, dan Payment.
6.  Participant melihat instruksi Virtual Account simulasi.
7.  Backend memproses simulasi pembayaran.
8.  Jika berhasil, Order menjadi PAID.
9.  Backend menerbitkan tiket satu per Attendee.
10. Sistem mengirim email e-ticket.

## 8.3 Registrasi Dibantu Owner/Staff

1.  Owner/Staff membuka event yang dapat diakses.
2.  Sistem memeriksa permission `ASSIST_REGISTRATION`.
3.  Pengguna mengisi data pemesan dan peserta.
4.  Backend memeriksa kuota, periode penjualan, dan batas pembelian.
5.  Backend membuat struktur Order yang sama dengan registrasi mandiri.
6.  `registration_method` diisi `ASSISTED`.
7.  `assisted_by_member_id` mencatat Owner/Staff yang melakukan
    tindakan.
8.  Pembayaran diproses menggunakan simulasi yang sama.
9.  Tiket diterbitkan setelah pembayaran berhasil atau pesanan gratis
    berhasil.

Tidak boleh ada jalur khusus yang melewati validasi kuota, harga, atau
pembayaran.

## 8.4 Check-in Online

1.  Owner/Staff membuka scanner pada event yang ditugaskan.
2.  Backend memeriksa permission scanner/check-in.
3.  QR dipindai.
4.  Backend memvalidasi token, event, status pembayaran, status tiket,
    dan izin pengguna.
5.  Jika valid dan belum digunakan, backend mencatat check-in secara
    atomik.
6.  Status tiket berubah menjadi CHECKED_IN.
7.  Dashboard memperbarui statistik.

## 8.5 Check-in Offline Terbatas

1.  Data validasi event disinkronkan sebelum koneksi terputus.
2.  Scanner menyimpan hasil lokal ke antrean.
3.  UI menampilkan bahwa hasil offline belum diverifikasi server.
4.  Ketika koneksi kembali, data dikirim untuk sinkronisasi.
5.  Backend memvalidasi ulang.
6.  Konflik tiket yang digunakan pada lebih dari satu perangkat ditandai
    untuk pemeriksaan.

Offline multi-perangkat dengan konsistensi penuh bukan target MVP.
Jangan menjanjikan pencegahan duplikasi sempurna ketika perangkat tidak
terhubung.

## 8.6 Penanganan Keluhan

1.  Participant/Organizer mengirim laporan.
2.  Sistem membuat nomor laporan dan token akses aman.
3.  Admin membuka daftar keluhan.
4.  Admin memeriksa detail.
5.  Admin membalas atau menambahkan catatan internal.
6.  Admin memperbarui status.
7.  Pelapor memeriksa perkembangan laporan melalui tautan aman.
8.  Laporan ditutup setelah penyelesaian.

------------------------------------------------------------------------

# 9. Status dan Aturan Bisnis

## 9.1 Status Event

Status yang disarankan: - `DRAFT` - `PENDING_REVIEW` -
`REVISION_REQUESTED` - `APPROVED` - `PUBLISHED` - `REJECTED` -
`SUSPENDED` - `COMPLETED` - `CANCELLED`

`APPROVED` dan `PUBLISHED` dapat menjadi status terpisah: disetujui
berarti lolos moderasi, sedangkan dipublikasikan berarti sudah tersedia
untuk umum.

## 9.2 Status Order

-   `PENDING_PAYMENT`
-   `PAID`
-   `EXPIRED`
-   `CANCELLED`

Status Order dan Payment disimpan terpisah.

## 9.3 Status Payment

-   `PENDING`
-   `PAID`
-   `EXPIRED`
-   `FAILED`
-   `CANCELLED`

## 9.4 Status Ticket

-   `VALID`
-   `CHECKED_IN`
-   `CANCELLED`
-   `REVOKED`

## 9.5 Status Invitation

-   `PENDING`
-   `ACCEPTED`
-   `EXPIRED`
-   `REVOKED`

## 9.6 Status Subscription

-   `ACTIVE`
-   `PENDING_PAYMENT`
-   `EXPIRED`
-   `CANCELLED`
-   `SUSPENDED`

## 9.7 Aturan Tiket dan Kuota

1.  Tiket hanya diterbitkan setelah pembayaran dikonfirmasi backend atau
    pesanan gratis dinyatakan berhasil.
2.  Setiap tiket memiliki token unik dan sulit ditebak.
3.  Satu tiket hanya boleh memiliki satu check-in sukses.
4.  Tiket yang dibatalkan/dicabut tidak dapat digunakan.
5.  Kuota diperiksa dan diperbarui dengan transaksi database.
6.  Kuota yang ditahan oleh Order pending harus dilepaskan saat Order
    expired/cancelled.
7.  Proses pembayaran dan penerbitan tiket harus idempoten.
8.  Harga pada OrderItem disimpan sebagai snapshot.
9.  Perubahan harga TicketType tidak mengubah Order lama.

## 9.8 Aturan Paket dan Komisi

1.  Paket gratis tetap memiliki data Plan.
2.  Organizer memiliki paket aktif sesuai aturan langganan.
3.  Batas fitur diperiksa oleh backend.
4.  Perubahan paket dicatat dalam SubscriptionHistory.
5.  Nilai komisi/biaya transaksi disimpan sebagai snapshot.
6.  Perubahan pengaturan komisi tidak mengubah transaksi historis.
7.  Pendapatan platform harus dibedakan dari gross ticket sales.

------------------------------------------------------------------------

# 10. Rancangan Database dan ERD Konseptual

Database menggunakan PostgreSQL dengan Prisma ORM. Nama tabel berikut
adalah rancangan konseptual. Detail tipe data, indeks, constraint, dan
relasi final harus ditetapkan pada schema Prisma.

## 10.1 Identity & Access

  -----------------------------------------------------------------------
  Model                               Fungsi
  ----------------------------------- -----------------------------------
  `User`                              Semua akun dengan global role
                                      PARTICIPANT, ORGANIZER, atau ADMIN.

  `OrganizerProfile`                  Profil tambahan Organizer.

  `EventMember`                       Keanggotaan User pada Event dengan
                                      role OWNER atau STAFF.

  `EventMemberPermission`             Permission per anggota pada event.

  `EventInvitation`                   Undangan Staff yang memiliki token
                                      dan masa berlaku.
  -----------------------------------------------------------------------

## 10.2 Event Management

  Model               Fungsi
  ------------------- ------------------------------------------------------
  `EventCategory`     Kategori umum event.
  `Event`             Data event.
  `EventModeration`   Riwayat keputusan moderasi Admin.
  `TicketType`        Kategori tiket, harga, kuota, dan periode penjualan.

## 10.3 Registration & Payment

  -----------------------------------------------------------------------
  Model                               Fungsi
  ----------------------------------- -----------------------------------
  `EventOrder`                        Pesanan, sumber registrasi,
                                      pemesan, total, dan status.

  `OrderItem`                         Rincian kategori tiket dan jumlah
                                      dalam pesanan.

  `Attendee`                          Data setiap orang yang akan
                                      menggunakan tiket.

  `OrderPayment`                      Pembayaran simulasi atau pembayaran
                                      yang kelak diintegrasikan.
  -----------------------------------------------------------------------

## 10.4 Ticket & Check-in

  Model                   Fungsi
  ----------------------- ---------------------------------------------------
  `Ticket`                E-ticket individual dengan token QR unik.
  `ScanLog`               Semua percobaan scan, termasuk gagal dan offline.
  `CheckIn`               Catatan check-in yang telah diproses.
  `TicketEmailDelivery`   Status pengiriman email tiket dan retry.

## 10.5 Subscription & Revenue

  -----------------------------------------------------------------------
  Model                               Fungsi
  ----------------------------------- -----------------------------------
  `Plan`                              Paket layanan.

  `PlanFeature`                       Fitur dan batas penggunaan paket.

  `Subscription`                      Paket yang digunakan Organizer.

  `SubscriptionHistory`               Riwayat perubahan langganan.

  `SubscriptionPayment`               Pembayaran paket berbayar.

  `PlatformTransaction`               Pencatatan pendapatan platform dari
                                      tiket atau paket.
  -----------------------------------------------------------------------

## 10.6 Support & Administration

  -----------------------------------------------------------------------
  Model                               Fungsi
  ----------------------------------- -----------------------------------
  `SupportReport`                     Laporan/keluhan Participant atau
                                      Organizer.

  `SupportReportActivity`             Balasan, catatan internal, dan
                                      perubahan status laporan.

  `PlatformSetting`                   Pengaturan global platform.

  `PlatformSettingHistory`            Riwayat perubahan pengaturan.

  `AuditLog`                          Jejak tindakan penting.
  -----------------------------------------------------------------------

## 10.7 Relasi Konseptual Utama

``` mermaid
erDiagram
    USER ||--o| ORGANIZER_PROFILE : has
    USER ||--o{ EVENT_MEMBER : joins
    EVENT ||--o{ EVENT_MEMBER : has
    EVENT_MEMBER ||--o{ EVENT_MEMBER_PERMISSION : grants
    EVENT ||--o{ EVENT_INVITATION : invites
    EVENT ||--o{ EVENT_MODERATION : moderation
    EVENT_CATEGORY ||--o{ EVENT : categorizes
    EVENT ||--o{ TICKET_TYPE : offers

    USER o|--o{ EVENT_ORDER : places
    EVENT ||--o{ EVENT_ORDER : receives
    EVENT_MEMBER o|--o{ EVENT_ORDER : assists
    EVENT_ORDER ||--|{ ORDER_ITEM : contains
    TICKET_TYPE ||--o{ ORDER_ITEM : selected
    ORDER_ITEM ||--|{ ATTENDEE : has
    EVENT_ORDER ||--o{ ORDER_PAYMENT : payments
    ATTENDEE ||--o| TICKET : receives
    TICKET ||--o{ SCAN_LOG : scanned
    TICKET ||--o{ CHECK_IN : checkins

    PLAN ||--o{ PLAN_FEATURE : contains
    USER ||--o{ SUBSCRIPTION : subscribes
    PLAN ||--o{ SUBSCRIPTION : selected
    SUBSCRIPTION ||--o{ SUBSCRIPTION_HISTORY : history
    SUBSCRIPTION ||--o{ SUBSCRIPTION_PAYMENT : payments

    EVENT_ORDER o|--o{ PLATFORM_TRANSACTION : records
    SUBSCRIPTION o|--o{ PLATFORM_TRANSACTION : records

    USER o|--o{ SUPPORT_REPORT : submits
    SUPPORT_REPORT ||--o{ SUPPORT_REPORT_ACTIVITY : activities
    USER ||--o{ AUDIT_LOG : performs
```

Catatan: - Peserta tanpa akun tetap dapat memiliki Order dan Attendee.
`user_id` pada Order boleh kosong. - EventOrder menyimpan
`registration_method` bernilai `SELF_SERVICE` atau `ASSISTED`. - Untuk
registrasi dibantu, `assisted_by_member_id` menunjuk EventMember yang
melakukan registrasi. - EventMemberPermission hanya berlaku pada event
terkait. - Constraint satu Owner aktif per event harus dijamin oleh
backend dan/atau database. - Satu tiket hanya boleh memiliki satu
CheckIn sukses. ScanLog boleh menyimpan banyak percobaan. -
PlatformTransaction harus memiliki tepat satu sumber transaksi yang
valid: Order atau Subscription. - Model database dapat disesuaikan saat
implementasi selama seluruh kebutuhan dan aturan bisnis PRD tetap
terpenuhi.

------------------------------------------------------------------------

# 11. Persyaratan Fungsional

## 11.1 Autentikasi dan Akun

-   **FR-01:** Organizer dapat mendaftar dengan nama, email, dan
    password.
-   **FR-02:** Sistem menyediakan login dan logout.
-   **FR-03:** Password harus disimpan dalam bentuk hash.
-   **FR-04:** Participant dapat melakukan pemesanan tanpa akun.
-   **FR-05:** Akun Participant opsional dapat menyimpan riwayat
    pesanan/tiket.
-   **FR-06:** Staff hanya memperoleh akses setelah menerima undangan
    valid.
-   **FR-07:** Admin tidak dapat dibuat melalui registrasi umum.
-   **FR-08:** Backend memeriksa role, status akun, keanggotaan event,
    dan permission pada setiap endpoint privat.

## 11.2 Event dan Moderasi

-   **FR-09:** Organizer Owner dapat membuat dan mengedit event.
-   **FR-10:** Event baru berstatus DRAFT.
-   **FR-11:** Owner dapat mengajukan event untuk moderasi.
-   **FR-12:** Admin dapat menyetujui, menolak, atau meminta revisi.
-   **FR-13:** Event yang belum disetujui tidak dapat dipesan publik.
-   **FR-14:** Event yang dipublikasikan memiliki URL publik.
-   **FR-15:** QR publik event mengarah ke halaman event/registrasi dan
    berbeda dari QR tiket individual.
-   **FR-16:** Admin dapat menangguhkan event dengan alasan dan audit
    log.

## 11.3 Kategori Tiket dan Kuota

-   **FR-17:** Owner dapat membuat beberapa TicketType.
-   **FR-18:** TicketType memiliki nama, deskripsi, harga, kuota,
    periode penjualan, dan status.
-   **FR-19:** Sistem membatasi pemesanan berdasarkan kuota.
-   **FR-20:** Sistem mendukung beberapa tiket dalam satu Order.
-   **FR-21:** Kuota dikelola secara aman untuk mencegah overselling.
-   **FR-22:** Perubahan harga tidak mengubah Order lama.

## 11.4 Registrasi dan Order

-   **FR-23:** Participant dapat mendaftar melalui URL publik tanpa
    akun.
-   **FR-24:** Participant dapat memilih kategori dan jumlah tiket.
-   **FR-25:** Sistem meminta data setiap Attendee.
-   **FR-26:** Sistem menampilkan ringkasan harga dan biaya sebelum
    Order dibuat.
-   **FR-27:** Sistem membuat nomor Order unik.
-   **FR-28:** Order memiliki batas waktu pembayaran.
-   **FR-29:** Kuota yang ditahan dilepas saat Order expired/cancelled.
-   **FR-30:** Owner dapat membantu registrasi.
-   **FR-31:** Staff dapat membantu registrasi hanya jika memiliki
    permission `ASSIST_REGISTRATION`.
-   **FR-32:** Registrasi mandiri dan dibantu menggunakan proses backend
    yang sama.
-   **FR-33:** Sistem menyimpan metode registrasi dan identitas pelaku
    registrasi.

## 11.5 Simulasi Pembayaran

-   **FR-34:** MVP menyediakan simulasi Virtual Account.
-   **FR-35:** Sistem menampilkan nomor VA simulasi, nominal, referensi,
    dan batas waktu.
-   **FR-36:** Status Payment mencakup PENDING, PAID, EXPIRED, FAILED,
    atau CANCELLED.
-   **FR-37:** Backend memverifikasi perubahan status.
-   **FR-38:** Frontend tidak dapat memalsukan status PAID.
-   **FR-39:** Pembayaran berhasil memicu penerbitan tiket.
-   **FR-40:** Pembayaran expired tidak menghasilkan tiket aktif.
-   **FR-41:** Proses konfirmasi yang dipanggil berulang tidak boleh
    membuat tiket ganda.

## 11.6 E-Ticket dan Email

-   **FR-42:** Setiap Attendee yang memenuhi syarat memperoleh tiket
    individual.
-   **FR-43:** Setiap tiket memiliki ID dan token QR unik.
-   **FR-44:** QR tidak memuat password atau data pribadi lengkap.
-   **FR-45:** Participant dapat membuka e-ticket.
-   **FR-46:** Sistem mengirim e-ticket melalui email.
-   **FR-47:** Kegagalan email tidak menghapus tiket yang sudah
    diterbitkan.
-   **FR-48:** Sistem menyimpan status pengiriman dan menyediakan retry.
-   **FR-49:** Status tiket minimal VALID, CHECKED_IN, CANCELLED, dan
    REVOKED.

## 11.7 Scanner dan Check-in

-   **FR-50:** Owner dapat membuka scanner pada event miliknya.
-   **FR-51:** Staff dapat membuka scanner hanya jika memiliki
    permission.
-   **FR-52:** Backend memeriksa token, event, pembayaran, status tiket,
    dan permission.
-   **FR-53:** Check-in online dilakukan secara atomik.
-   **FR-54:** Tiket yang sudah digunakan ditolak.
-   **FR-55:** Sistem mencatat waktu, tiket, event, dan pelaku check-in.
-   **FR-56:** Scanner menampilkan hasil valid, sudah digunakan, tidak
    valid, salah event, dibatalkan, atau gangguan jaringan.
-   **FR-57:** Mode offline terbatas hanya menggunakan data yang telah
    disinkronkan.
-   **FR-58:** Check-in offline ditandai belum terverifikasi server.
-   **FR-59:** Konflik sinkronisasi harus ditandai untuk pemeriksaan.

## 11.8 Manajemen Staff

-   **FR-60:** Owner dapat mengundang Staff melalui email/tautan aman.
-   **FR-61:** Undangan memiliki masa berlaku.
-   **FR-62:** Staff harus menerima undangan.
-   **FR-63:** Owner dapat mengatur permission.
-   **FR-64:** Owner dapat mencabut akses.
-   **FR-65:** Staff hanya dapat mengakses event yang ditugaskan.

## 11.9 Dashboard Organizer

-   **FR-66:** Dashboard menampilkan statistik event milik Organizer.
-   **FR-67:** Owner dapat melihat daftar peserta, Order, Payment, dan
    check-in.
-   **FR-68:** Owner dapat mencari dan memfilter peserta.
-   **FR-69:** Sistem mencatat metode registrasi mandiri/dibantu.
-   **FR-70:** Owner dapat melihat laporan penjualan dan kehadiran.
-   **FR-71:** Ekspor CSV tersedia sesuai prioritas dan hak paket.
-   **FR-72:** Owner dapat melihat aktivitas event.
-   **FR-73:** Staff hanya melihat menu dan data sesuai permission.

## 11.10 Paket dan Langganan

-   **FR-74:** Admin dapat membuat, mengubah, mengaktifkan,
    menonaktifkan, dan mengarsipkan paket.
-   **FR-75:** Paket mendukung gratis dan berbayar.
-   **FR-76:** Setiap paket dapat memiliki fitur dan batas penggunaan.
-   **FR-77:** Organizer dapat melihat paket dan langganan sendiri.
-   **FR-78:** Backend memeriksa batas fitur paket sebelum mengizinkan
    tindakan.
-   **FR-79:** Riwayat perubahan paket/langganan disimpan.

## 11.11 Dashboard dan Manajemen Bisnis Admin

-   **FR-80:** Admin dapat melihat total event, event aktif, mendatang,
    selesai, dan menunggu moderasi.
-   **FR-81:** Admin dapat melihat jumlah Organizer dan Participant.
-   **FR-82:** Admin dapat melihat jumlah Order dan tiket.
-   **FR-83:** Admin dapat melihat transaksi dan pendapatan platform.
-   **FR-84:** Admin dapat memfilter dashboard berdasarkan periode.
-   **FR-85:** Admin dapat melihat grafik perkembangan event, pengguna,
    penjualan, dan pendapatan.
-   **FR-86:** Admin dapat melihat dan mengelola semua event.
-   **FR-87:** Admin dapat melihat dan mengelola akun sesuai kewenangan.
-   **FR-88:** Penangguhan event/akun harus menyimpan alasan dan
    AuditLog.

## 11.12 Transaksi dan Pendapatan

-   **FR-89:** Admin dapat melihat transaksi tiket dan pembayaran paket.
-   **FR-90:** Sistem membedakan gross ticket sales dari platform
    revenue.
-   **FR-91:** Sistem mencatat nilai komisi/biaya sebagai snapshot
    transaksi.
-   **FR-92:** Perubahan konfigurasi biaya tidak mengubah transaksi
    lama.
-   **FR-93:** Pendapatan paket dan komisi tiket ditampilkan terpisah.

## 11.13 Keluhan dan Support

-   **FR-94:** Participant dapat mengirim laporan tanpa akun.
-   **FR-95:** Organizer dapat mengirim keluhan terkait platform.
-   **FR-96:** Sistem membuat nomor laporan dan token status aman.
-   **FR-97:** Admin dapat mencari, memfilter, dan membuka laporan.
-   **FR-98:** Admin dapat mengatur prioritas dan status.
-   **FR-99:** Admin dapat membalas pelapor dan membuat catatan
    internal.
-   **FR-100:** Riwayat aktivitas laporan disimpan.
-   **FR-101:** Catatan internal tidak ditampilkan kepada pelapor.

## 11.14 Pengaturan dan Audit

-   **FR-102:** Admin dapat mengelola pengaturan platform yang
    diizinkan.
-   **FR-103:** Perubahan komisi/biaya harus tercatat.
-   **FR-104:** Tindakan administratif penting dicatat di AuditLog.
-   **FR-105:** AuditLog tidak dapat diubah oleh pengguna biasa.
-   **FR-106:** Admin dapat mencari dan memfilter audit log.

------------------------------------------------------------------------

# 12. Persyaratan Nonfungsional

## 12.1 Keamanan

-   Password disimpan menggunakan hashing yang sesuai.
-   Endpoint privat wajib menggunakan autentikasi dan otorisasi.
-   Semua pemeriksaan kepemilikan event dilakukan backend.
-   Permission Staff diperiksa di backend untuk setiap tindakan.
-   Token QR dan token laporan harus sulit ditebak.
-   QR tidak memuat informasi pribadi lengkap.
-   Secret/API key disimpan melalui environment variables/secret
    manager.
-   Admin tidak dapat memperoleh hak akses melalui manipulasi request.
-   Aksi sensitif dicatat pada audit log.

## 12.2 Konsistensi Data

-   Kuota tidak boleh oversold.
-   Pembayaran idempoten.
-   Penerbitan tiket idempoten.
-   Check-in online atomik.
-   Satu tiket hanya memiliki satu check-in sukses.
-   Perubahan harga/paket tidak mengubah transaksi historis.
-   Sinkronisasi offline mendeteksi konflik.

## 12.3 Kegunaan

-   UI modern, bersih, profesional, dan responsif.
-   Dashboard Organizer dan Admin menggunakan sidebar pada desktop.
-   Navigasi mobile dapat menggunakan drawer/bottom navigation yang
    sesuai.
-   Form memiliki validasi dan pesan error yang jelas.
-   Status Order, Payment, Ticket, Event, dan Support ditampilkan
    konsisten.
-   Halaman publik dapat dibuka langsung melalui URL.

## 12.4 Keandalan

-   API memiliki format response/error konsisten.
-   Kegagalan email tidak merusak penerbitan tiket.
-   Gangguan jaringan ditampilkan dengan jelas.
-   Operasi penting memiliki log.
-   Operasi transaksi menggunakan database transaction jika melibatkan
    beberapa tabel.

## 12.5 Privasi

-   Data yang dikumpulkan hanya yang dibutuhkan.
-   Data peserta dibatasi berdasarkan role dan event.
-   Data laporan publik hanya dapat dibuka dengan token aman.
-   Password, token rahasia, dan credential tidak ditampilkan di log.
-   Kebijakan privasi dan ketentuan layanan disiapkan sebelum peluncuran
    publik.

------------------------------------------------------------------------

# 13. Rancangan Teknis: Frontend Saat Ini dan Arsitektur Target

## 13.1 Frontend (Tahap Saat Ini)

-   Flutter dan Dart untuk seluruh tampilan aplikasi.
-   Provider atau state management yang sudah digunakan proyek; jangan
    mengganti pendekatan yang ada tanpa alasan teknis.
-   Data dummy lokal melalui model dan mock repository/service.
-   Navigasi antarhalaman dan perubahan state pada prototype harus dapat
    berjalan tanpa backend; audit workspace menunjukkan kondisi aplikasi
    saat ini belum sepenuhnya memenuhi kriteria tersebut (bagian 20).
-   `mobile_scanner` dapat menggunakan mode simulasi/mock jika perangkat
    atau integrasi belum disiapkan.
-   `qr_flutter` dapat digunakan untuk menampilkan QR contoh.
-   Android dan Web menjadi target tampilan; layout harus menyesuaikan
    ukuran layar mobile dan desktop/web.
-   Komponen UI tidak boleh bergantung langsung pada data hardcoded di
    dalam widget jika data tersebut berpotensi berubah atau digunakan
    lintas halaman.

## 13.2 Backend dan Database (Tahap Berikutnya)

Bagian ini merupakan rancangan teknologi target dan **belum menjadi
ruang lingkup implementasi saat ini**.

-   Backend: Node.js dan Express.
-   ORM: Prisma.
-   Database: PostgreSQL.
-   JWT/session sesuai rancangan autentikasi.
-   Middleware autentikasi dan otorisasi.
-   Validasi input, layanan email, logging, dan error handling.
-   Service untuk order, payment simulation, ticket issuance, check-in,
    subscription, support, dan audit.

## 13.3 Prinsip Arsitektur Target (Saat Integrasi Backend)

-   Controller menangani HTTP request/response.
-   Service menangani aturan bisnis.
-   Repository/data access menggunakan Prisma.
-   Middleware menangani autentikasi, role, dan permission.
-   Validasi bisnis tidak diletakkan hanya di frontend.
-   Hindari duplikasi proses antara registrasi mandiri dan registrasi
    dibantu.
-   Pisahkan status Order, Payment, Ticket, dan CheckIn.

## 13.4 Rancangan Kontrak API untuk Tahap Integrasi

Endpoint berikut merupakan kelompok awal, bukan kontrak final.

**Auth** - `POST /auth/register` - `POST /auth/login` -
`POST /auth/logout` - `GET /auth/me`

**Public Events** - `GET /public/events` - `GET /public/events/:slug` -
`POST /public/events/:eventId/orders`

**Organizer Events** - `GET /organizer/events` -
`POST /organizer/events` - `GET /organizer/events/:eventId` -
`PATCH /organizer/events/:eventId` -
`POST /organizer/events/:eventId/submit-review`

**Ticket Types** - `POST /organizer/events/:eventId/ticket-types` -
`PATCH /organizer/ticket-types/:ticketTypeId` -
`DELETE /organizer/ticket-types/:ticketTypeId` (hanya jika aman dan
belum memiliki transaksi)

**Assisted Registration** -
`POST /organizer/events/:eventId/assisted-orders`

**Orders and Payments** - `GET /orders/:orderId` -
`POST /orders/:orderId/payment-simulation` -
`GET /orders/:orderId/payment-status`

**Tickets and Check-in** - `GET /me/tickets` -
`GET /tickets/:ticketId` - `POST /check-in/validate` -
`POST /check-in/confirm` - `POST /check-in/sync`

**Event Members** - `GET /organizer/events/:eventId/members` -
`POST /organizer/events/:eventId/invitations` -
`POST /invitations/:token/accept` -
`PATCH /organizer/events/:eventId/members/:memberId/permissions` -
`DELETE /organizer/events/:eventId/members/:memberId`

**Admin** - `GET /admin/dashboard` - `GET /admin/events` -
`POST /admin/events/:eventId/approve` -
`POST /admin/events/:eventId/reject` -
`POST /admin/events/:eventId/request-revision` -
`POST /admin/events/:eventId/suspend` - `GET /admin/users` -
`GET /admin/plans` - `POST /admin/plans` -
`PATCH /admin/plans/:planId` - `GET /admin/subscriptions` -
`GET /admin/transactions` - `GET /admin/revenue`

**Support** - `POST /support/reports` - `GET /support/reports/:token` -
`GET /admin/support/reports` - `GET /admin/support/reports/:reportId` -
`PATCH /admin/support/reports/:reportId`

Payload, response, pagination, validasi, status code, dan format error
harus ditetapkan dalam kontrak API terpisah sebelum implementasi
frontend-backend paralel.

------------------------------------------------------------------------

# 14. Strategi Pengujian dan Acceptance Criteria

## 14.1 Pengujian Role dan Permission

-   Participant tidak dapat mengakses dashboard Organizer/Admin.
-   Organizer hanya dapat mengakses event miliknya atau event yang
    ditugaskan.
-   Staff tidak dapat membuka event lain dengan mengganti ID.
-   Staff tanpa `ASSIST_REGISTRATION` tidak dapat membuat registrasi
    bantuan.
-   Staff tanpa permission scanner tidak dapat melakukan scan/check-in.
-   Staff tidak dapat mengubah harga, kuota, atau pengaturan event.
-   Owner dapat mencabut akses Staff dan akses tersebut langsung ditolak
    backend.
-   Admin dapat mengakses fungsi administratif sesuai role.

## 14.2 Pengujian Event

-   Organizer membuat event.
-   Event tersimpan sebagai DRAFT.
-   Organizer mengajukan moderasi.
-   Admin meminta revisi.
-   Organizer memperbaiki dan mengajukan ulang.
-   Admin menyetujui.
-   Event dipublikasikan dan URL publik dapat diakses.
-   Event yang belum disetujui tidak dapat dipesan.

## 14.3 Pengujian Registrasi dan Pembayaran

-   Registrasi mandiri tanpa akun berhasil.
-   Registrasi dibantu Owner berhasil.
-   Registrasi dibantu Staff dengan permission berhasil.
-   Staff tanpa permission ditolak.
-   Kedua metode menggunakan struktur Order/Payment/Ticket yang sama.
-   Kuota tidak melebihi batas.
-   Pembayaran berhasil menerbitkan tiket.
-   Pembayaran gagal/expired tidak menerbitkan tiket aktif.
-   Proses pembayaran berulang tidak membuat tiket ganda.

## 14.4 Pengujian Ticket dan Check-in

-   QR valid diterima.
-   QR tidak valid ditolak.
-   QR dari event lain ditolak.
-   QR yang sudah digunakan ditolak.
-   Dua scan online bersamaan hanya menghasilkan satu check-in sukses.
-   Pelaku check-in tercatat.
-   Offline scan diberi status belum terverifikasi.
-   Konflik offline terdeteksi ketika sinkronisasi.

## 14.5 Pengujian Admin

-   Dashboard menampilkan agregasi sesuai definisi.
-   Event aktif tidak memasukkan event mendatang.
-   Gross ticket sales tidak disamakan dengan platform revenue.
-   Admin dapat membuat/mengubah paket.
-   Batas fitur paket diperiksa backend.
-   Admin dapat melihat transaksi tiket dan paket.
-   Admin dapat menangani laporan.
-   Perubahan pengaturan dan tindakan sensitif tercatat di AuditLog.

## 14.6 Pengujian UI

-   Browser desktop.
-   Browser mobile.
-   Android dengan kamera yang didukung.
-   Halaman publik dapat dibuka melalui URL langsung.
-   Sidebar Organizer hanya menampilkan menu sesuai status Owner/Staff
    dan permission.
-   Sidebar Admin hanya tampil untuk Admin.
-   Form menampilkan pesan validasi dan error yang jelas.
-   Loading, empty state, dan error state tersedia.

------------------------------------------------------------------------

# 15. Prioritas Pengembangan

## Tahap 0 --- UI/Frontend Prototype (Fokus Saat Ini)

Tahap ini adalah prioritas pengerjaan sekarang. Tidak ada backend atau
database yang perlu dibuat sebagai bagian dari tahap ini. Folder backend
dan migrasi yang sudah ada di workspace dicatat sebagai artefak aktual,
bukan instruksi untuk memperluas ruang lingkup frontend (lihat bagian
20).

-   Audit struktur proyek Flutter dan pertahankan pola/arsitektur yang
    sudah berjalan dengan baik.
-   Bangun kerangka aplikasi dan navigasi untuk area publik,
    Participant, Organizer Owner, Organizer Staff, dan Admin.
-   Implementasikan seluruh halaman sesuai daftar pada bagian 3--6.
-   Buat komponen UI reusable dan desain responsif untuk Android serta
    Flutter Web.
-   Gunakan data dummy terpusat dan mock service/repository.
-   Simulasikan interaksi dan perubahan state tanpa request jaringan.
-   Sediakan state loading, empty, error, success, dan akses terbatas
    untuk menguji tampilan.
-   Uji alur antarhalaman dan perbedaan tampilan berdasarkan role serta
    permission dummy.
-   Pastikan aplikasi dapat dijalankan dan diuji tanpa server/backend.

**Kriteria selesai Tahap 0:** semua halaman prioritas dapat dibuka,
navigasi berjalan, data dummy tampil konsisten, interaksi utama dapat
didemonstrasikan, tampilan responsif, dan tidak ada ketergantungan pada
backend/API/database.

## Tahap 1 --- Fondasi Backend (Setelah UI Prototype)

-   Auth dan User.
-   Role global.
-   OrganizerProfile.
-   Event dan EventMember.
-   Permission dasar.
-   Struktur layout publik, Organizer, dan Admin.

## Tahap 2 --- Integrasi Event dan Moderasi

-   CRUD event.
-   TicketType.
-   Moderasi Admin.
-   URL publik.
-   QR registrasi publik.

## Tahap 3 --- Integrasi Registrasi dan Pembayaran

-   Registrasi mandiri.
-   Registrasi dibantu Owner/Staff.
-   Order, OrderItem, Attendee.
-   Simulasi Virtual Account.
-   Kuota dan expiry.

## Tahap 4 --- Integrasi E-Ticket dan Check-in

-   Penerbitan Ticket.
-   Email delivery.
-   QR scanner.
-   Check-in online.
-   Riwayat scan.
-   Offline terbatas dan sinkronisasi.

## Tahap 5 --- Integrasi Operasional Organizer

-   Dashboard.
-   Peserta dan Order.
-   Manajemen Staff.
-   Permission.
-   Laporan event.
-   Riwayat aktivitas.

## Tahap 6 --- Integrasi Operasional Admin

-   Dashboard bisnis.
-   Manajemen pengguna.
-   Keluhan/support center.
-   Audit log.
-   Manajemen event global.

## Tahap 7 --- Integrasi Monetisasi

-   Plan dan PlanFeature.
-   Subscription.
-   Pembayaran paket simulasi jika diperlukan.
-   PlatformTransaction.
-   Monitoring komisi dan pendapatan.
-   Enforcement batas fitur.

Paket gratis dan berbayar merupakan keputusan produk, tetapi integrasi
pembayaran sungguhan dan payout dapat dikembangkan setelah MVP stabil.

------------------------------------------------------------------------

# 16. Fitur di Luar MVP

Fitur berikut tidak boleh dianggap wajib pada implementasi awal:

-   Payment gateway sungguhan.
-   Pencairan dana otomatis ke Organizer.
-   Refund otomatis.
-   Kupon dan promosi kompleks.
-   Referral.
-   Notifikasi WhatsApp/SMS.
-   Live chat.
-   Bantuan berbasis AI.
-   Analitik lanjutan.
-   Multi-currency.
-   Multi-bahasa.
-   Offline multi-perangkat dengan konsistensi penuh.
-   Pemisahan Admin menjadi beberapa sub-role.
-   Aplikasi iOS yang dipublikasikan resmi.
-   Ekspor PDF/Excel lanjutan jika belum menjadi prioritas.

------------------------------------------------------------------------

# 17. Keputusan yang Masih Terbuka

Hal berikut belum ditetapkan secara final. AI dan developer tidak boleh
membuat asumsi permanen tanpa persetujuan:

1.  Besaran komisi platform.
2.  Apakah biaya layanan ditanggung Participant, Organizer, atau
    keduanya.
3.  Harga paket Basic/Pro/Enterprise.
4.  Durasi paket: bulanan, tahunan, atau keduanya.
5.  Batas waktu pembayaran Order.
6.  Batas operasional untuk kuota yang disebut tidak terbatas.
7.  Detail kebijakan pembatalan dan refund.
8.  Mekanisme final undangan Staff (email, tautan, atau keduanya).
9.  Batas cache dan perangkat untuk offline check-in.
10. Kebijakan retensi dan penghapusan data.
11. Hosting dan deployment.
12. Jadwal rilis dan pembagian sprint.

Nilai contoh yang ditampilkan dalam PRD bukan keputusan tarif final.

------------------------------------------------------------------------

# 18. Instruksi Implementasi untuk AI Developer

Dokumen ini merupakan acuan kebutuhan produk. Untuk kondisi proyek saat
ini, AI developer wajib mengerjakan frontend prototype dengan data dummy
saja. Saat diminta mengembangkan aplikasi, ikuti aturan berikut:

1.  Baca PRD secara keseluruhan sebelum mengubah kode.
2.  Periksa struktur repository dan implementasi aktual terlebih dahulu.
    Jangan menganggap nama folder, file, atau modul sudah sesuai PRD.
3.  Untuk tahap saat ini, jangan membuat backend, database, migration,
    endpoint, API client, atau request HTTP.
4.  Gunakan data dummy dan mock service/repository yang terpisah dari
    widget. Buat struktur yang mudah diganti dengan implementasi API
    nantinya.
5.  Jangan mengubah fitur di luar ruang lingkup tugas tanpa alasan dan
    persetujuan.
6.  Jangan mengarang halaman, permission, atau status yang
    bertentangan dengan PRD.
7.  Jika ada kebutuhan yang belum ditetapkan, jelaskan asumsi dan minta
    keputusan sebelum menerapkan perubahan permanen.
8.  Terapkan role global hanya PARTICIPANT, ORGANIZER, ADMIN.
    OWNER/STAFF adalah membership role pada event. Untuk prototype,
    simulasi role dan permission menggunakan data dummy.
9.  Registrasi mandiri dan assisted registration harus memiliki alur UI
    yang konsisten meskipun prosesnya masih disimulasikan.
10. Jangan menganggap status pembayaran, penerbitan tiket, atau
    keberhasilan check-in dari frontend sebagai transaksi sungguhan.
11. Gunakan nama status dan permission yang konsisten di seluruh
    halaman dan model frontend.
12. Pertahankan rancangan agar dapat diintegrasikan dengan backend pada
    tahap berikutnya tanpa membangun backend sekarang.
13. Setelah implementasi, jalankan pemeriksaan dan pengujian yang
    sesuai, lalu laporkan file yang berubah, fitur yang selesai, hasil
    pengujian, dan pekerjaan yang belum selesai.
14. Jangan mengklaim fitur selesai jika belum diuji.
15. Aturan keamanan server, transaksi database, migration, dan API pada
    PRD berlaku saat tahap backend dimulai, bukan untuk tahap UI saat ini.

------------------------------------------------------------------------

# 19. Status Dokumen

**Status acuan produk: fokus pengembangan adalah frontend Flutter dengan
data dummy. Status kode aktual workspace pada 2026-11-05 dirinci pada
bagian 20; workspace memuat backend/API dan implementasi frontend yang
belum sepenuhnya menjadi prototype dummy terintegrasi.**

PRD ini menggabungkan kebutuhan dasar E-Ticket Event QR Scanner dengan
keputusan terbaru:

-   Tiga role global: Participant, Organizer, Admin.
-   Staff menjadi membership pada event, bukan role global.
-   Owner dapat mengatur permission Staff per event.
-   Registrasi tersedia secara mandiri dan dibantu.
-   Pembayaran MVP menggunakan simulasi Virtual Account.
-   Paket Organizer terdiri dari gratis dan berbayar.
-   Platform memiliki komisi/biaya layanan sebagai jalur monetisasi.
-   Admin merupakan satu role dengan kewenangan platform penuh untuk
    MVP.
-   Admin memiliki dashboard bisnis, manajemen paket, transaksi,
    keluhan, pengguna, dan audit log.

Dokumen ini menjadi acuan utama kebutuhan produk dan rancangan halaman.
Untuk tahap sekarang, gunakan PRD ini terutama sebagai acuan halaman,
fitur, hak akses tampilan, dan interaksi frontend berbasis data dummy.
Detail database Prisma, kontrak API, dan integrasi backend baru
dikerjakan pada tahap berikutnya. Desain visual final dapat disesuaikan
selama tidak mengubah kebutuhan produk dan aturan role yang telah
ditetapkan.

------------------------------------------------------------------------

# 20. Audit Implementasi dan Struktur Repository (2026-11-05)

Bagian ini membedakan **kebutuhan/rancangan produk** dari **fakta yang
ditemukan pada workspace saat audit**. Audit hanya membaca file; source
program tidak diubah untuk menyelaraskannya dengan PRD. Struktur di bawah
adalah struktur aktual pada workspace saat audit, bukan struktur ideal
yang diwajibkan. File hasil generate/build/dependency seperti
`apps/.dart_tool/`, `apps/build/`, dan `backend/node_modules/` tidak
dirinci.

## 20.1 Struktur Repository Aktual

```text
repository/
├── prd.md                         # Acuan kebutuhan produk dan status/audit ini
├── README.md                      # Ringkasan repository
├── LAPORAN_PEMBAGIAN_TUGAS_MOBILE.txt # Catatan pembagian tugas
├── apps/                          # Workspace aplikasi Flutter aktual
│   ├── lib/                       # Source Flutter/Dart
│   │   ├── main.dart              # Entry point, menjalankan MyApp
│   │   ├── pubspec.yaml           # Manifest tambahan yang ada di dalam lib/
│   │   ├── app.dart               # MaterialApp, AuthGate, RoleGuard
│   │   ├── app_router.dart        # Generator route dan pemeriksaan role
│   │   ├── routes/                # Konstanta route dan generator route lain
│   │   ├── core/                  # Config, konstanta, error, API client,
│   │   │                          # session, theme, utilitas, validator
│   │   ├── features/              # Screen/widget dikelompokkan per fitur
│   │   │   ├── admin/             # Dashboard, moderasi, akun, laporan, tab
│   │   │   ├── auth/              # Login, daftar, edit profil, widget auth
│   │   │   ├── check_in/          # Screen check-in dan riwayat
│   │   │   ├── events/            # Daftar/detail event dan kartu
│   │   │   ├── home/              # Beranda publik
│   │   │   ├── notifications/    # Daftar notifikasi
│   │   │   ├── orders/            # Daftar dan detail order
│   │   │   ├── organizer/         # Dashboard, event, peserta, staf, tab
│   │   │   ├── payments/          # Pembayaran dan status
│   │   │   ├── registration/      # Registrasi, pilihan tiket, form peserta
│   │   │   ├── reports/           # Form, daftar, status laporan
│   │   │   ├── scanner/           # Scanner, hasil scan, placeholder scanner
│   │   │   ├── staff/             # Dashboard Staff
│   │   │   └── tickets/           # Daftar/detail tiket dan tampilan QR
│   │   ├── models/                # Model check-in, event, order, payment,
│   │   │                          # report, ticket, user
│   │   ├── providers/             # ChangeNotifier untuk auth dan fitur
│   │   └── services/              # API/auth/event/order/payment dan service
│   ├── test/                      # Widget test (saat audit: widget_test.dart)
│   ├── android/, ios/, web/,      # Platform Flutter; linux, macos, windows
│   │   linux/, macos/, windows/   # juga tersedia pada workspace
│   ├── pubspec.yaml/lock          # Konfigurasi dan lock dependency Flutter
│   └── analysis_options.yaml      # Konfigurasi analisis Dart
└── backend/                       # Backend aktual yang ada di workspace
    ├── server.js                  # Entry server
    ├── src/
    │   ├── app.js                 # Konfigurasi aplikasi Express
    │   ├── config/                # Konfigurasi environment dan Supabase
    │   ├── controllers/           # Handler auth, event, ticket, admin
    │   ├── middleware/            # Auth, role, validasi, error, not-found
    │   ├── models/                # Representasi User, Event, Ticket
    │   ├── routes/                # Route auth, event, ticket, admin
    │   ├── services/              # Auth, QR, seed
    │   ├── utils/                 # Konstanta dan response
    │   └── validators/            # Validator auth dan ticket
    └── supabase/migrations/       # Migrasi SQL yang ada pada workspace
```

Catatan nama/lokasi: indeks Git masih mencatat Flutter lama pada
`apps/mobile/` (termasuk source dan platform), sedangkan filesystem
workspace saat audit mempunyai source aktif di `apps/lib/` dan platform
langsung di `apps/`; `apps/mobile/` masih ada tetapi hanya berisi folder
`build/` pada pemeriksaan filesystem, bukan source proyek aktif. Status
Git juga menunjukkan banyak penghapusan `apps/mobile/` dan file baru/tidak
terlacak di `apps/`. Selain manifest Flutter di `apps/pubspec.yaml`, ada
manifest lain `apps/lib/pubspec.yaml`; peran manifest kedua ini tidak
ditentukan oleh audit dan tidak boleh diasumsikan sebagai package yang
digunakan. Audit ini tidak menyimpulkan penyebab perubahan atau
memindahkan, memulihkan, maupun menghapus apa pun. Gunakan filesystem
checkout yang sedang dikerjakan sebagai rujukan saat membaca source, dan
tinjau perubahan Git terpisah sebelum tindakan yang dapat mengubah file.

Pemetaan struktur di atas menjelaskan tanggung jawab direktori, bukan
jaminan bahwa seluruh modul telah tersambung atau selesai. Contohnya,
folder `providers/` dan `services/` berisi kelas state/service, tetapi
banyak screen belum menggunakan data tersebut atau masih memanggil API.

## 20.2 Entry Point, Routing, dan Pengelolaan State Aktual

- Entry point `apps/lib/main.dart` menjalankan `MyApp`.
- `apps/lib/app.dart` memasang `AuthProvider` dengan `AuthService`,
  menginisialisasi pemulihan sesi, mengatur theme Material, route awal,
  `AuthGate`, dan `RoleGuard` untuk dashboard Organizer/Admin.
- Routing terbelah antara `apps/lib/app_router.dart` (generator utama
  yang dipasang di `MaterialApp`) dan `apps/lib/routes/app_router.dart`
  serta `app_routes.dart` (generator/konstanta tambahan). Keduanya bukan
  satu peta navigasi terpusat yang sudah lengkap. Beberapa route bernama
  terdaftar tetapi tidak menghasilkan screen yang sesuai; generator
  tambahan mengembalikan placeholder untuk kebanyakan path. Rute Staff
  scanner saat ini diarahkan ke dashboard Staff, bukan scanner.
- Auth guard hanya membedakan pengguna tanpa sesi, `admin`, dan
  `organizer`; pengguna ber-role `attendee`/`staff` tidak diarahkan ke
  halaman Participant atau Staff oleh `_homeForRole`. Pengamanan route
  ini bukan pengganti otorisasi produk/server dan belum merupakan
  implementasi matriks permission per event.
- State memakai `provider` (`ChangeNotifier`), model pada `models/`,
  dan kelas `services/`. Provider fitur memiliki pola loading/error,
  tetapi audit tidak menemukan aliran dummy lokal yang menghubungkan
  seluruh screen; beberapa service menggunakan `ApiClient`/HTTP.
- Konfigurasi `MOCK_MODE` default `true` dan akun demo pada
  `AuthService` hanya mencakup Admin dan Organizer. Login demo dapat
  berjalan lokal; registrasi demo sengaja menolak pendaftaran. Pada
  mode non-mock, auth memakai endpoint HTTP. `ApiClient` menggunakan
  `http`, base URL default `10.0.2.2:5000/api`, serta token sesi melalui
  `flutter_secure_storage`; nilai default bukan bukti bahwa server
  tersedia.
- `apps/lib/core/` menjadi tempat theme, config, constants, validator,
  error, API client, dan session service. `apps/lib/models/` memiliki
  model User/role, Event/TicketType, Order/OrderItem, Payment, Ticket,
  CheckIn, dan SupportReport/ReportActivity. `providers/` dan
  `services/` tidak menyediakan implementasi mock terpisah untuk semua
  fitur; tidak ada dasar untuk menyatakan semua alur memakai dummy.
- `apps/test/widget_test.dart` menguji sebagian alur auth, dashboard
  Organizer/Admin, notifikasi, dan edit profil; keberadaan test itu tidak
  membuktikan semua route atau kebutuhan PRD telah selesai.

## 20.3 Inventaris Screen Flutter dan Status Bukti Implementasi

Nama screen di bawah adalah file yang ada pada filesystem audit.
Keberadaan file menunjukkan implementasi awal/kerangka, bukan bahwa alur
produk lengkap, route terhubung, permission benar, atau transaksi
berfungsi. Status "kerangka/placeholder" merujuk bukti eksplisit pada
UI/kode; fitur yang tidak terverifikasi harus dianggap belum tervalidasi,
bukan diasumsikan selesai.

| Area/role | Screen atau komponen aktual | Temuan audit dan batasan |
|---|---|---|
| Publik/Participant | `home/home_screen.dart`, `events/event_list_screen.dart`, `events/event_detail_screen.dart`, `events/event_card.dart` | Beranda dan daftar event menyatakan data akan ditambahkan setelah provider/API tersedia; daftar adalah stub. Detail event ada, namun alur publik lengkap tidak terbukti tersambung. |
| Auth/akun | `auth/login_screen.dart`, `auth/register_screen.dart`, `auth/profile_edit_screen.dart`, `auth/widgets/auth_divider.dart` | Login dan pemulihan sesi demo Admin/Organizer ada; daftar demo menolak pendaftaran; edit profil memiliki state/screen. Belum membuktikan alur Participant mandiri maupun auth seluruh role. |
| Registrasi | `registration/registration_screen.dart`, `ticket_selection_screen.dart`, `attendee_form_screen.dart` | File ada; order/attendee/kuota terpadu dan alur sukses/gagal lengkap tidak terverifikasi dari router/provider. |
| Order/pembayaran | `orders/order_list_screen.dart`, `order_detail_screen.dart`, `payments/payment_screen.dart`, `payment_status_screen.dart` | File ada; provider/service ada dan payment provider menawarkan operasi simulasi, tetapi tidak membuktikan simulasi offline terhubung atau tiket hanya terbit setelah pembayaran valid. |
| Tiket | `tickets/ticket_list_screen.dart`, `ticket_detail_screen.dart`, `widgets/qr_ticket_display.dart` | File dan komponen QR ada; penerbitan/persistensi/verifikasi tiket produksi bukan bagian yang terbukti. |
| Laporan Participant/publik | `reports/report_form_screen.dart`, `report_list_screen.dart`, `report_status_screen.dart` | Form laporan secara eksplisit masih TODO tanpa submit dan menyatakan API belum tersedia. Alur buat/status laporan belum selesai. |
| Notifikasi | `notifications/notification_list_screen.dart` | Screen ada; dashboard memanggil screen, tetapi test menunjukkan pesan daftar notifikasi akan ditampilkan. Bukan sistem notifikasi terintegrasi. |
| Check-in/Scanner | `check_in/check_in_screen.dart`, `check_in_history_screen.dart`, `scanner/scanner_screen.dart`, `scan_result_screen.dart`, `scanner_placeholder.dart` | Ada screen dan placeholder scanner. Tidak ditemukan dependency scanner `mobile_scanner` pada `pubspec.yaml`; scan kamera, QR validasi, check-in idempoten, offline sync dan konflik belum terbukti tersedia. |
| Organizer Owner | `organizer/organizer_dashboard_screen.dart`, `organizer_profile_screen.dart`, `event_management_screen.dart`, `event_form_screen.dart`, `attendee_list_screen.dart`, `staff_management_screen.dart`, `tabs/organizer_tab_controller.dart` | Dashboard memiliki UI tindakan tambah event/profil/notifikasi; beberapa screen event/staff memanggil `EventService` jaringan. Tab controller eksplisit placeholder. Kepemilikan, CRUD lengkap, permission, undangan/status/riwayat dan export belum dapat dianggap terpenuhi. |
| Organizer Staff | `staff/staff_dashboard_screen.dart` | Stub eksplisit, belum berisi daftar event/tugas dan menyatakan integrasi provider/API belum tersedia. Tidak ada screen navigasi Staff berbasis permission yang selesai. |
| Admin | `admin/admin_dashboard_screen.dart`, `event_moderation_screen.dart`, `account_management_screen.dart`, `report_management_screen.dart`, `tabs/admin_tab_controller.dart` | Dashboard memuat event melalui service dan menampilkan loading/error; akun memiliki screen, dan screen moderasi/laporan tersedia. Controller tab eksplisit placeholder. Navigasi/fitur paket, subscription, transaksi, pendapatan, analytics, pengaturan dan audit log sesuai rancangan PRD belum terverifikasi sebagai UI aktif lengkap. |

## 20.4 Audit Halaman, Navigasi, dan Hak Akses per Role

Matriks dan kebutuhan lengkap pada bagian 2--6, 8--11 tetap merupakan
rancangan produk yang berlaku; status aktual berikut **tidak menghapus
atau mengurangi** persyaratan tersebut.

| Role/rancangan | Cakupan kebutuhan yang tetap wajib dalam PRD | Keadaan kode saat audit |
|---|---|---|
| Participant | Beranda/daftar/detail event, registrasi mandiri, pilihan tiket dan data attendee, konfirmasi/order, pembayaran, tiket/QR, riwayat order, profil, notifikasi, laporan tanpa akun/status | Banyak file screen ada, tetapi belum ada alur Participant yang dapat dicapai konsisten dari auth gate (role attendee tidak diarahkan ke home). Beranda/daftar, laporan dan notifikasi mempunyai placeholder/stub yang terlihat; routing tidak menghubungkan seluruh alur. |
| Organizer Owner | Dashboard, daftar/buat/edit/detail event, kategori dan registrasi, peserta/order, registrasi dibantu, tim dan permission Staff, scanner/check-in, laporan, aktivitas, profil/notifikasi | Dashboard dan sejumlah screen ada; beberapa layanan memanggil backend. Tab kosong placeholder; keseluruhan navigasi dan fitur sesuai permission/paket belum terhubung atau terbukti. |
| Organizer Staff | Dashboard/event yang ditugaskan; hanya menu dan data untuk permission per-event; registrasi dibantu, peserta, scanner/check-in, riwayat/laporan jika diizinkan | Dashboard hanya stub; tidak ada penyaringan UI berbasis permission yang terbukti. Enum `UserRole.staff` terdapat di model, tetapi AuthGate/router tidak mengarahkan role itu dengan benar dan membership per-event belum dibuktikan di frontend. |
| Admin | Dashboard bisnis; moderasi/event; akun; paket/langganan; transaksi dan pendapatan; support; laporan/analitik; pengaturan; audit log; profil/notifikasi | Dashboard/Admin screen dasar ada; beberapa data memakai service HTTP. Tab masih placeholder. Navigasi route `/admin/...` dapat berakhir di dashboard generik; seluruh modul bisnis yang dirancang belum terbukti terimplementasi. |

Peta route yang didefinisikan pada `apps/lib/routes/app_routes.dart`
mencakup nama untuk auth/home/event/registration/payment/order/ticket,
Organizer, Staff, laporan, notifikasi, dan beberapa halaman Admin. Namun
generator utama tidak menangani semua nama tersebut secara eksplisit;
untuk sebagian besar path ia hanya memetakan detail event/tiket,
pengelolaan Staff atau guard dashboard, dan tidak meneruskan seluruh
parameter route yang dibutuhkan ke screen fitur. Karena itu daftar route
tidak boleh ditafsirkan sebagai bukti bahwa semua halaman sudah dapat
dinavigasi.

Hak akses per-event OWNER/STAFF serta daftar permission yang dirinci pada
bagian 2 tetap menjadi satu-satunya rancangan akses produk. Model
frontend memuat enum global `attendee`, `organizer`, `staff`, `admin`,
sedangkan keputusan PRD menetapkan tiga role global dan Staff sebagai
membership event. Ketidaksesuaian representasi kode ini adalah item
sinkronisasi implementasi, bukan persetujuan untuk mengubah skema role
PRD. Jangan menyamakan guard route sederhana dengan enforcement
permission, kepemilikan, keamanan, atau audit yang disyaratkan.

## 20.5 Ketidaksesuaian, Kesiapan UI, dan Panduan State

1. **Struktur repository:** dokumentasi lama yang mengacu `apps/mobile/`
   tidak cocok dengan lokasi source aktif pada filesystem saat audit
   (`apps/lib/`, `apps/test/`, dan platform berada di bawah `apps/`),
   meskipun direktori `apps/mobile/build/` masih ada. Indeks Git dan
   workspace berbeda karena perubahan yang sedang berlangsung; audit
   tidak menyimpulkan perpindahan final atau mengubah status file.
2. **Backend/API:** teks PRD sebelumnya yang menyatakan backend belum
   dibuat tidak cocok dengan adanya `backend/server.js`, source Express,
   konfigurasi Supabase, dan migration pada workspace. Sementara itu,
   arahan tahap frontend-only tetap berlaku: jangan mengembangkan atau
   mengintegrasikan backend sebagai bagian dari UI prototype tanpa
   perubahan ruang lingkup yang disetujui. Beberapa Flutter service dan
   `ApiClient` sudah ada dan melakukan HTTP ketika `MOCK_MODE=false`;
   ini bukan bukti semua data saat ini dummy atau API siap produksi.
3. **Role:** rancangan global Participant/Organizer/Admin dan Staff
   membership per-event tidak cocok dengan enum kode yang juga
   mendefinisikan `staff` sebagai `UserRole`. Selain itu, AuthGate tidak
   menyediakan landing Participant/Staff yang benar. Pertahankan
   rancangan PRD; jangan menyelesaikan perbedaan dengan mengubah skema
   tanpa keputusan.
4. **Navigasi:** dua file generator/konstanta routing menimbulkan peta
   route yang terpecah; banyak route PRD belum terhubung. Tab Organizer
   dan Admin serta landing event/Staff masih berupa placeholder.
5. **Data dan simulasi:** terdapat mock login terbatas untuk Admin dan
   Organizer, model/provider/service dan operasi simulasi tertentu.
   Tidak terverifikasi bahwa katalog event, registrasi mandiri/dibantu,
   status pembayaran/order, penerbitan QR, scan/check-in, laporan,
   langganan, atau dashboard Admin menggunakan fixture dummy end-to-end.
   Jangan klaim transaksi bisnis terjadi hanya karena UI mengubah state.
6. **Dependency/test:** dependency Flutter yang tercantum meliputi
   `http`, `flutter_secure_storage`, dan `provider`; tidak tercantum
   `mobile_scanner` atau `qr_flutter`. Test widget yang ada bersifat
   parsial dan mengandung assertion atas dashboard saat ini, bukan
   verifikasi seluruh persyaratan/role.

Untuk semua halaman yang dibangun berdasarkan PRD, dokumentasikan dan
implementasikan state UI berikut bila sesuai konteks: **loading** yang
tidak menggandakan aksi; **empty** dengan penjelasan dan tindakan
lanjutan; **success** dengan konfirmasi dan navigasi/status yang jelas;
**error** yang dapat dipahami beserta retry bila aman; **access denied**
tanpa membocorkan data; serta **form validation** dan **confirmation**
untuk tindakan destruktif. Untuk prototype, sediakan state tersebut
dengan fixture/service dummy terkontrol, termasuk hasil sukses/gagal,
tanpa membuat request jaringan atau mengklaim keberhasilan backend.
Status implementasi setiap halaman harus dilabeli sebagai salah satu:

- **Ada/terbukti sebagian:** file atau interaksi UI ditemukan; tidak
  berarti semua requirement halaman terpenuhi.
- **Placeholder/stub:** screen/controller secara eksplisit menampilkan
  konten sementara, TODO, atau belum melakukan aksi.
- **Rancangan PRD/belum terverifikasi:** kebutuhan tetap wajib, namun
  implementasi yang berjalan belum ditemukan atau tidak dapat dibuktikan
  dari source yang diaudit.

## 20.6 Rekonsiliasi dengan Keputusan Produk

Temuan implementasi di bagian ini adalah backlog/ketidaksesuaian, bukan
perubahan keputusan produk. Tetap berlaku tanpa pengurangan:

- Tiga role global Participant, Organizer, Admin; Owner/Staff adalah
  membership per-event dan permission Staff dapat ditentukan Owner.
- Semua nama dan cakupan permission, larangan Staff, prinsip akses
  least-privilege, registrasi mandiri dan dibantu, alur Order/Payment/
  Ticket, pembayaran simulasi Virtual Account, status, aturan kuota,
  paket/komisi, moderasi, pelaporan, audit, dan skema konseptual yang
  telah didefinisikan di bagian sebelumnya.
- Seluruh halaman/rancangan pada bagian 3--6, persyaratan fungsional
  FR-01--FR-106, persyaratan nonfungsional, serta tahapan implementasi.
  Tidak ada bagian tersebut yang dibatalkan karena file belum tersedia.
- Fokus tahap UI Flutter tetap data dummy; keberadaan backend/API di
  workspace hanya fakta repository dan tidak memberi instruksi untuk
  membangun backend sekarang.

Saat melanjutkan pengembangan, AI Developer harus membaca struktur
workspace terbaru dan bagian ini, kemudian menandai requirement satu per
satu sebagai terpenuhi, parsial, placeholder, atau belum dikerjakan.
Jangan mengubah skema/permission/alur yang telah disepakati untuk
menyesuaikan keterbatasan kode saat ini. Bila perlu memperbarui status
audit, tambahkan bukti implementasi terbaru tanpa menghapus keputusan
produk terdahulu.

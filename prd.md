# Product Requirements Document (PRD)
## E-Ticket Event QR Scanner

- **Versi:** 0.1 — Draf untuk validasi
- **Status:** Belum final
- **Platform:** Flutter Android dan Flutter Web
- **Backend:** Node.js + Express
- **Database:** PostgreSQL + Prisma ORM
- **Target pasar awal:** Indonesia
- **Tim pengembang:** 3 orang

---

## 1. Ringkasan Produk

### 1.1 Deskripsi

E-Ticket Event QR Scanner adalah platform pengelolaan dan penjualan tiket acara yang memungkinkan penyelenggara membuat event, mengatur kategori tiket, mengelola peserta, memantau pembayaran, serta melakukan validasi tiket menggunakan QR Code.

Peserta dapat menemukan event dan mendaftar melalui tautan publik tanpa wajib menginstal aplikasi atau membuat akun. Setelah pembayaran berhasil dikonfirmasi, sistem menerbitkan e-ticket dengan QR Code unik yang dapat ditampilkan melalui halaman tiket dan dikirimkan melalui email.

Penyelenggara dapat mengundang staf untuk membantu operasional acara, termasuk melakukan pemindaian tiket dan check-in. Platform juga menyediakan sistem laporan kendala agar peserta dapat menghubungi admin ketika mengalami masalah.

MVP menggunakan pembayaran simulasi. Arsitektur disiapkan agar integrasi payment gateway sungguhan dapat dilakukan pada tahap berikutnya.

### 1.2 Visi Produk

Menyediakan platform event ticketing yang mudah digunakan, profesional, dan dapat dikembangkan menjadi layanan komersial untuk berbagai jenis penyelenggara acara.

### 1.3 Tujuan Produk

1. Mempermudah penyelenggara membuat dan memublikasikan event.
2. Memudahkan peserta melakukan registrasi dan memperoleh tiket.
3. Mengurangi penggunaan tiket palsu dan check-in ganda.
4. Membantu penyelenggara mengelola kategori tiket, kuota, peserta, dan staf.
5. Menyediakan informasi pembayaran dan check-in secara terstruktur.
6. Menyediakan saluran pelaporan masalah bagi peserta.
7. Menyiapkan fondasi bisnis melalui biaya layanan pada transaksi tiket berbayar.

### 1.4 Indikator Keberhasilan MVP

MVP dianggap berhasil apabila:

- Penyelenggara dapat membuat event dan mengajukannya untuk moderasi.
- Admin dapat menyetujui atau menolak event.
- Peserta dapat mendaftar melalui browser.
- Sistem dapat memproses pesanan dan simulasi pembayaran.
- Tiket diterbitkan hanya setelah pembayaran terkonfirmasi.
- QR Code tiket dapat divalidasi.
- Check-in ganda dapat dicegah dalam kondisi online.
- Mode offline memiliki mekanisme sinkronisasi dan penanganan konflik.
- Peserta dapat membuat laporan kendala dan admin dapat menindaklanjutinya.
- Aplikasi dapat dijalankan pada Android dan browser.

---

## 2. Target Pengguna dan Peran

### 2.1 Peserta

Pengguna yang ingin mengikuti acara.

Hak dan kemampuan:
- Melihat daftar serta detail event.
- Mendaftar tanpa wajib membuat akun.
- Memilih kategori dan jumlah tiket.
- Mengisi data peserta.
- Melakukan simulasi pembayaran.
- Melihat status pesanan.
- Mengakses e-ticket.
- Menerima tiket melalui email.
- Melaporkan kendala.
- Melihat status laporan melalui tautan atau mekanisme identifikasi laporan.

Peserta yang membuat akun secara opsional dapat memperoleh fitur tambahan seperti riwayat pesanan dan pengelolaan tiket dalam satu akun.

### 2.2 Penyelenggara (Organizer)

Pengguna yang mengelola event miliknya sendiri.

Hak dan kemampuan:
- Membuat dan mengedit event.
- Mengatur lokasi, jadwal, deskripsi, dan informasi acara.
- Membuat beberapa kategori tiket.
- Mengatur harga, kuota, dan periode penjualan setiap kategori.
- Mengajukan event untuk moderasi.
- Melihat daftar peserta dan status pembayaran.
- Mencari dan memfilter peserta.
- Mengekspor data peserta ke CSV atau Excel, sesuai prioritas implementasi.
- Mengundang dan mencabut akses staf.
- Melihat statistik penjualan dan check-in.
- Melihat riwayat aktivitas terkait event.

Penyelenggara hanya boleh mengakses event yang menjadi tanggung jawabnya.

### 2.3 Staf Event

Pengguna yang memperoleh akses melalui undangan penyelenggara.

Hak dan kemampuan:
- Melihat event yang aksesnya diberikan.
- Membuka fitur scanner.
- Memvalidasi tiket sesuai izin.
- Melakukan check-in peserta.
- Melihat hasil pemindaian yang relevan.

Staf tidak otomatis memiliki hak mengubah harga, kuota, data pembayaran, atau pengaturan event.

### 2.4 Admin Platform

Pengelola platform secara keseluruhan.

Hak dan kemampuan:
- Meninjau event yang diajukan.
- Menyetujui atau menolak publikasi event.
- Meninjau laporan kendala peserta.
- Mengelola status laporan.
- Menangani masalah akun, pesanan, dan tiket sesuai kewenangan.
- Melihat riwayat tindakan admin.
- Mengawasi aktivitas platform.

Admin platform tidak boleh mengubah data penting tanpa jejak audit.

---

## 3. Cakupan MVP

### 3.1 Fitur Wajib

1. Autentikasi penyelenggara, staf, dan admin.
2. Registrasi peserta tanpa akun.
3. Daftar dan detail event publik.
4. Pembuatan serta moderasi event.
5. Pengelolaan kategori dan kuota tiket.
6. Pemesanan satu atau beberapa tiket.
7. Simulasi pembayaran Virtual Account.
8. Status pembayaran dan kedaluwarsa pesanan.
9. Penerbitan e-ticket dan QR Code unik.
10. Pengiriman e-ticket melalui email.
11. Riwayat tiket untuk peserta yang memiliki akun.
12. Scanner QR dan validasi tiket.
13. Check-in online serta dukungan mode offline terbatas.
14. Manajemen staf melalui undangan.
15. Dashboard dan laporan dasar penyelenggara.
16. Riwayat aktivitas penting.
17. Formulir laporan kendala peserta.
18. Dashboard admin untuk moderasi dan penanganan laporan.

### 3.2 Fitur yang Ditunda

- Payment gateway sungguhan.
- Refund dan pembatalan dana otomatis.
- Aplikasi iOS yang telah diuji dan dipublikasikan secara resmi.
- Notifikasi WhatsApp atau SMS.
- Paket premium berlangganan.
- Sistem promosi dan kupon kompleks.
- Analitik lanjutan.
- Multi-currency dan dukungan multibahasa.
- Sistem offline multi-perangkat dengan konsistensi penuh.

---

## 4. Persyaratan Fungsional

### 4.1 Autentikasi dan Akun

- **FR-01:** Penyelenggara dapat mendaftarkan akun menggunakan data yang diperlukan, termasuk nama, email, dan kata sandi.
- **FR-02:** Sistem menyediakan login dan logout bagi pengguna yang memiliki akun.
- **FR-03:** Kata sandi harus disimpan dalam bentuk hash yang aman, bukan teks biasa.
- **FR-04:** Peserta dapat melakukan pemesanan tanpa membuat akun.
- **FR-05:** Staf hanya dapat mengakses event setelah menerima dan menggunakan undangan yang valid.
- **FR-06:** Admin memiliki akses terpisah dan tidak dapat memperoleh hak admin hanya melalui formulir registrasi umum.

### 4.2 Event

- **FR-07:** Penyelenggara dapat membuat event dengan informasi:
  - Nama event.
  - Deskripsi.
  - Gambar atau poster.
  - Kategori event.
  - Tanggal dan waktu mulai serta selesai.
  - Zona waktu.
  - Lokasi atau tautan acara online.
  - Jenis pelaksanaan: offline, online, atau hybrid.
  - Informasi kontak penyelenggara.
  - Status publikasi.
- **FR-08:** Event yang baru dibuat berstatus draf.
- **FR-09:** Penyelenggara dapat mengajukan event untuk ditinjau admin.
- **FR-10:** Admin dapat menyetujui, menolak, atau meminta revisi event.
- **FR-11:** Event yang belum disetujui tidak muncul sebagai event publik yang dapat dipesan.
- **FR-12:** Setiap event yang dipublikasikan memiliki URL publik yang dapat dibagikan.
- **FR-13:** Sistem menyediakan QR Code publik yang mengarah ke halaman event atau registrasi. QR ini berbeda dari QR tiket peserta.

### 4.3 Kategori dan Kuota Tiket

- **FR-14:** Penyelenggara dapat membuat beberapa kategori tiket dalam satu event, misalnya Regular, VIP, dan Early Bird.
- **FR-15:** Setiap kategori tiket memiliki nama, harga, kuota, periode penjualan, dan status aktif.
- **FR-16:** Sistem membatasi pemesanan berdasarkan kuota yang tersedia.
- **FR-17:** Sistem mendukung batas jumlah tiket per pesanan.
- **FR-18:** Penyelenggara dapat memilih kuota terbatas atau kuota tanpa batas nominal yang ditentukan sebelumnya. Pilihan tanpa batas tetap tunduk pada batas operasional, kapasitas infrastruktur, dan aturan event.
- **FR-19:** Kuota harus diperiksa dan diperbarui secara aman di backend untuk mencegah overselling akibat pesanan bersamaan.

### 4.4 Registrasi dan Pemesanan

- **FR-20:** Peserta dapat membuka halaman event melalui browser tanpa wajib memasang aplikasi.
- **FR-21:** Peserta dapat memilih kategori dan jumlah tiket.
- **FR-22:** Sistem menampilkan ringkasan pesanan, harga, biaya layanan jika berlaku, dan total pembayaran sebelum konfirmasi.
- **FR-23:** Peserta mengisi informasi yang diperlukan untuk setiap tiket, misalnya nama dan email peserta.
- **FR-24:** Sistem membuat pesanan dengan nomor referensi unik.
- **FR-25:** Pesanan memiliki batas waktu pembayaran yang dapat dikonfigurasi berdasarkan aturan platform.
- **FR-26:** Kuota tiket yang dipesan harus dikelola selama periode pembayaran. Ketika pesanan kedaluwarsa atau dibatalkan, kuota yang ditahan harus dilepaskan.

### 4.5 Simulasi Pembayaran

- **FR-27:** MVP menyediakan metode simulasi Virtual Account.
- **FR-28:** Sistem menampilkan nomor VA simulasi dan petunjuk penyelesaian pembayaran.
- **FR-29:** Status pembayaran minimal mencakup Pending, Paid, Expired, serta Failed atau Cancelled jika dibutuhkan.
- **FR-30:** Perubahan status pembayaran dilakukan dan diverifikasi oleh backend.
- **FR-31:** Tombol simulasi pembayaran tidak boleh menjadi mekanisme yang dapat digunakan pengguna untuk memalsukan status pembayaran melalui perubahan data klien.
- **FR-32:** Pembayaran yang berhasil memicu penerbitan tiket dan proses pengiriman email.
- **FR-33:** Pembayaran yang kedaluwarsa tidak menghasilkan tiket aktif dan kuotanya dilepaskan sesuai aturan sistem.
- **FR-34:** Sistem harus mencegah penerbitan tiket ganda ketika notifikasi atau proses konfirmasi pembayaran dijalankan berulang kali.

Catatan: Integrasi payment gateway sungguhan akan menggunakan mekanisme verifikasi resmi, seperti webhook yang diverifikasi, pada tahap pengembangan lanjutan.

### 4.6 Penerbitan dan Pengelolaan E-Ticket

- **FR-35:** Setiap tiket yang diterbitkan memiliki ID dan token unik.
- **FR-36:** QR Code individual tidak boleh berisi kata sandi, informasi pembayaran sensitif, atau data pribadi lengkap.
- **FR-37:** Peserta dapat membuka halaman e-ticket setelah pembayaran terkonfirmasi.
- **FR-38:** Sistem mengirimkan email berisi informasi tiket dan tautan akses e-ticket.
- **FR-39:** Jika pengiriman email gagal, tiket tetap tercatat secara benar dan sistem menyediakan status pengiriman serta mekanisme pengiriman ulang.
- **FR-40:** Setiap tiket mempunyai status minimal Valid dan Checked-in, serta Cancelled atau Revoked jika pembatalan didukung.
- **FR-41:** Peserta yang membeli beberapa tiket memperoleh identitas QR individual untuk setiap tiket.

### 4.7 Scanner dan Check-in

- **FR-42:** Staf yang memiliki izin dapat membuka scanner pada event yang ditugaskan.
- **FR-43:** Scanner memindai QR Code dan mengirim token tiket ke backend ketika online.
- **FR-44:** Backend memeriksa keaslian tiket, event terkait, status pembayaran, status tiket, dan hak akses staf.
- **FR-45:** Tiket yang valid dapat diubah menjadi status checked-in.
- **FR-46:** Proses check-in harus atomik agar dua pemindaian bersamaan tidak menghasilkan dua check-in sukses untuk tiket yang sama.
- **FR-47:** Scanner menampilkan hasil yang jelas:
  - Tiket valid dan check-in berhasil.
  - Tiket sudah digunakan.
  - Tiket tidak ditemukan atau tidak valid.
  - Tiket bukan untuk event tersebut.
  - Tiket dibatalkan.
  - Validasi gagal karena gangguan jaringan.
- **FR-48:** Sistem menyimpan waktu check-in, event, tiket, dan identitas staf yang melakukan pemindaian.

#### Mode Offline

- **FR-49:** Scanner menyediakan mode offline terbatas apabila data validasi yang diperlukan telah disinkronkan sebelumnya.
- **FR-50:** Check-in offline disimpan dalam antrean lokal untuk disinkronkan ketika jaringan kembali tersedia.
- **FR-51:** Sistem menampilkan status bahwa hasil check-in offline belum terverifikasi oleh server.
- **FR-52:** Jika dua perangkat menerima tiket yang sama ketika offline, sistem harus mendeteksi konflik saat sinkronisasi dan menandainya untuk pemeriksaan.
- **FR-53:** Mode offline tidak boleh diklaim memiliki pencegahan duplikasi sempurna ketika beberapa perangkat bekerja tanpa koneksi.

Catatan: Mode offline membutuhkan desain tambahan untuk data cache, masa berlaku cache, perlindungan penyimpanan lokal, dan resolusi konflik. Untuk tim kecil, implementasi awal sebaiknya dibatasi pada event yang telah disinkronkan dan skenario perangkat yang terkendali.

### 4.8 Manajemen Staf

- **FR-54:** Penyelenggara dapat mengundang staf melalui email atau tautan undangan yang aman.
- **FR-55:** Undangan memiliki masa berlaku dan hanya dapat digunakan sesuai aturan penerimaan undangan.
- **FR-56:** Penyelenggara dapat melihat status undangan dan daftar staf event.
- **FR-57:** Penyelenggara dapat mencabut akses staf.
- **FR-58:** Staf tidak boleh mengakses event lain hanya dengan mengubah ID event pada permintaan API.

### 4.9 Dashboard dan Laporan Penyelenggara

- **FR-59:** Dashboard menampilkan ringkasan event, jumlah tiket terjual, jumlah peserta, status pembayaran, dan check-in.
- **FR-60:** Penyelenggara dapat melihat daftar peserta dan mencari atau memfilter data.
- **FR-61:** Penyelenggara dapat melihat riwayat aktivitas yang relevan dengan event.
- **FR-62:** Sistem menyediakan laporan dasar penjualan dan check-in.
- **FR-63:** Ekspor data peserta ke CSV menjadi target fitur pendukung; ekspor Excel dapat menyusul jika waktu pengembangan terbatas.

### 4.10 Laporan Kendala dan Bantuan Admin

- **FR-64:** Peserta dapat mengirim laporan kendala melalui formulir publik atau tautan bantuan.
- **FR-65:** Kategori laporan mencakup pembayaran belum terkonfirmasi, tiket belum diterima, QR Code tidak dapat digunakan, kesalahan data peserta, kendala registrasi, pembatalan/refund jika didukung, dan kendala lainnya.
- **FR-66:** Formulir meminta informasi minimum yang diperlukan, seperti email kontak, nomor referensi pesanan jika ada, kategori masalah, dan deskripsi kendala.
- **FR-67:** Sistem membuat nomor tiket laporan agar peserta dapat merujuk laporan tersebut.
- **FR-68:** Peserta memperoleh konfirmasi bahwa laporan telah diterima.
- **FR-69:** Admin dapat melihat, mencari, dan memfilter laporan.
- **FR-70:** Admin dapat mengubah status laporan, misalnya Open, In Progress, Waiting for User, Resolved, dan Closed.
- **FR-71:** Sistem mencatat waktu pembuatan, perubahan status, dan identitas petugas yang menangani laporan.
- **FR-72:** Peserta dapat memeriksa status laporan melalui mekanisme yang aman, misalnya tautan status bertoken acak. Data laporan tidak boleh dapat dibaca hanya dengan menebak nomor tiket laporan.
- **FR-73:** Informasi kontak resmi platform dan panduan bantuan ditampilkan di halaman publik.

Batasan: fitur ini adalah sistem pengelolaan laporan internal, bukan live chat. Live chat, WhatsApp, dan pusat bantuan berbasis AI tidak termasuk MVP.

---

## 5. Alur Utama Sistem

### 5.1 Alur Penyelenggara

1. Penyelenggara membuat akun atau login.
2. Penyelenggara mengisi informasi event.
3. Penyelenggara membuat kategori tiket dan menentukan kuota.
4. Event disimpan sebagai draf.
5. Penyelenggara mengajukan event untuk moderasi.
6. Admin menyetujui atau meminta revisi.
7. Setelah disetujui dan dipublikasikan, event memiliki tautan publik dan QR Code registrasi.
8. Penyelenggara membagikan tautan kepada calon peserta.
9. Penyelenggara memantau pesanan, pembayaran, peserta, dan check-in.
10. Penyelenggara mengundang staf sesuai kebutuhan.

### 5.2 Alur Peserta

1. Peserta membuka tautan atau memindai QR publik event.
2. Peserta melihat detail event.
3. Peserta memilih kategori dan jumlah tiket.
4. Peserta mengisi data yang diperlukan.
5. Sistem membuat pesanan dan menampilkan ringkasan pembayaran.
6. Peserta memilih simulasi Virtual Account.
7. Sistem membuat instruksi pembayaran dan status pending.
8. Peserta menyelesaikan simulasi pembayaran.
9. Backend mengonfirmasi pembayaran.
10. Sistem menerbitkan QR Code unik untuk setiap tiket.
11. Peserta melihat halaman e-ticket dan menerima email.
12. Peserta menunjukkan QR Code pada hari acara.
13. Staf memindai tiket.
14. Sistem memvalidasi dan mencatat check-in.

### 5.3 Alur Laporan Kendala

1. Peserta membuka halaman bantuan.
2. Peserta memilih kategori masalah dan mengisi deskripsi.
3. Sistem memvalidasi input dan membuat laporan.
4. Peserta menerima nomor referensi atau tautan status.
5. Admin memeriksa dan mengubah status laporan.
6. Peserta dapat memeriksa perkembangan laporan.
7. Setelah solusi diberikan, laporan ditandai resolved atau closed.

---

## 6. Status dan Aturan Bisnis

### 6.1 Status Event

- Draft.
- Pending Review.
- Revision Required.
- Approved.
- Published.
- Rejected.
- Completed.
- Cancelled.

Status ini adalah usulan awal. Implementasi akhir dapat menyatukan atau memisahkan Approved dan Published sesuai kebutuhan.

### 6.2 Status Pesanan

- Pending Payment.
- Paid.
- Expired.
- Cancelled.

Status pembayaran sebaiknya disimpan terpisah dari status pesanan agar proses bisnis lebih jelas.

### 6.3 Aturan Tiket

1. Tiket hanya diterbitkan setelah pembayaran terkonfirmasi atau setelah pesanan gratis dinyatakan berhasil.
2. Setiap tiket memiliki token unik yang sulit ditebak.
3. Satu tiket hanya boleh menghasilkan satu check-in sukses.
4. Tiket yang dibatalkan atau dicabut tidak dapat digunakan.
5. Tiket harus terhubung ke event dan pesanan yang benar.
6. Kuota harus dijaga konsisten dalam transaksi database.
7. Status pembayaran dan penerbitan tiket harus idempoten, yaitu proses yang diulang tidak membuat hasil ganda.

### 6.4 Aturan Biaya Layanan

Platform direncanakan memperoleh pendapatan melalui komisi atau biaya layanan atas transaksi tiket berbayar.

Namun, besaran komisi, pihak yang menanggung biaya, metode penagihan, dan pencatatan pendapatan belum diputuskan.

Untuk MVP, biaya layanan dapat dibuat sebagai konfigurasi dengan nilai awal yang ditentukan tim. Nilai final wajib ditetapkan sebelum simulasi penjualan digunakan untuk demonstrasi bisnis.

---

## 7. Rancangan Halaman dan UI

### 7.1 Gaya Visual

- Modern dan profesional.
- Tampilan bersih dengan hierarki informasi yang jelas.
- Responsif pada ponsel, tablet, dan desktop.
- Formulir mudah digunakan.
- Status pembayaran, tiket, dan laporan ditampilkan secara jelas.
- Desain konsisten di Android dan Web.

Warna, tipografi, ikon, dan komponen desain detail ditetapkan pada tahap desain UI.

### 7.2 Halaman Publik

#### A. Beranda
- Identitas dan navigasi platform.
- Daftar event pilihan atau event terbaru.
- Kolom pencarian.
- Filter kategori dan tanggal jika termasuk prioritas.
- Tombol untuk membuka detail event.

#### B. Daftar Event
- Kartu event berisi poster, nama, tanggal, lokasi atau tipe event.
- Filter dan pencarian.
- Navigasi menuju detail event.

#### C. Detail Event
- Poster atau banner.
- Nama dan deskripsi.
- Jadwal dan lokasi.
- Informasi online/offline/hybrid.
- Daftar kategori tiket.
- Harga dan ketersediaan kuota.
- Tombol registrasi.
- Informasi kontak atau bantuan.

#### D. Registrasi
- Pilihan kategori dan jumlah tiket.
- Formulir data peserta.
- Email kontak untuk pengiriman tiket.
- Ringkasan harga dan biaya layanan.
- Persetujuan terhadap ketentuan yang berlaku.
- Tombol konfirmasi pesanan.

#### E. Pembayaran
- Nomor referensi pesanan.
- Nomor Virtual Account simulasi.
- Total yang harus dibayar.
- Batas waktu pembayaran.
- Status pembayaran.
- Tombol simulasi pembayaran untuk lingkungan MVP.
- Informasi jika pembayaran kedaluwarsa.

#### F. Halaman E-Ticket
- Nama event.
- Data peserta yang diperlukan.
- Kategori tiket.
- QR Code individual.
- Status tiket.
- Informasi jadwal dan lokasi.
- Tombol cetak atau unduh PDF jika berhasil masuk prioritas implementasi.

#### G. Bantuan dan Laporan Kendala
- Informasi kontak resmi.
- Pilihan kategori masalah.
- Formulir laporan.
- Nomor laporan setelah dikirim.
- Halaman pemeriksaan status laporan.

### 7.3 Halaman Peserta

#### A. Riwayat Pesanan
Untuk peserta yang memiliki akun:
- Daftar pesanan.
- Status pembayaran.
- Tautan menuju e-ticket.
- Informasi event.

#### B. Detail Pesanan
- Ringkasan pesanan.
- Status pembayaran.
- Daftar tiket yang terkait.
- Tautan bantuan untuk masalah pesanan.

Peserta tanpa akun menggunakan tautan akses pesanan yang aman, bukan halaman akun yang mewajibkan login.

### 7.4 Halaman Penyelenggara

#### A. Dashboard
- Total event.
- Tiket terjual.
- Pesanan menunggu pembayaran.
- Total check-in.
- Ringkasan penjualan.

#### B. Manajemen Event
- Daftar event.
- Status moderasi.
- Tombol membuat dan mengedit event.
- Tautan publik dan QR registrasi.

#### C. Formulir Event
- Informasi dasar.
- Jadwal.
- Lokasi atau tautan online.
- Poster.
- Kategori tiket.
- Kuota dan periode penjualan.
- Tombol simpan draf dan ajukan moderasi.

#### D. Manajemen Peserta
- Daftar peserta.
- Pencarian dan filter.
- Status pembayaran.
- Status check-in.
- Ekspor data sesuai kemampuan MVP.

#### E. Manajemen Staf
- Daftar staf event.
- Undangan staf.
- Status undangan.
- Pengaturan dan pencabutan akses.

#### F. Laporan Event
- Ringkasan pesanan dan tiket terjual.
- Pendapatan kotor.
- Biaya layanan jika sudah dikonfigurasi.
- Jumlah peserta check-in.
- Data yang dapat diekspor.

### 7.5 Halaman Staf

#### A. Daftar Event yang Ditugaskan
Hanya menampilkan event yang aksesnya dimiliki staf.

#### B. Scanner
- Tampilan kamera.
- Panduan pemindaian.
- Hasil validasi.
- Indikator koneksi online/offline.
- Status sinkronisasi check-in.

#### C. Riwayat Pemindaian
- Waktu pemindaian.
- Hasil pemindaian.
- Status sinkronisasi jika dilakukan secara offline.

### 7.6 Halaman Admin Platform

#### A. Dashboard Admin
- Jumlah event menunggu moderasi.
- Ringkasan laporan kendala.
- Ringkasan aktivitas administrasi.

#### B. Moderasi Event
- Detail event.
- Informasi penyelenggara.
- Tombol setujui, tolak, atau minta revisi.
- Alasan keputusan.

#### C. Manajemen Laporan
- Daftar laporan.
- Filter status dan kategori.
- Detail laporan.
- Catatan penanganan.
- Perubahan status.

#### D. Riwayat Administrasi
- Identitas petugas.
- Tindakan.
- Waktu tindakan.
- Referensi event atau laporan terkait.

---

## 8. Arsitektur Teknis

### 8.1 Mobile

Teknologi:
- Flutter dan Dart.
- Provider untuk state management.
- HTTP client untuk komunikasi REST API.
- `mobile_scanner` untuk pemindaian QR.
- `qr_flutter` untuk menampilkan QR Code.
- Shared Preferences untuk preferensi non-sensitif.

Satu proyek Flutter mendukung Android dan Web. Halaman dan navigasi disusun berdasarkan fitur, peran, dan kebutuhan platform.

### 8.2 Backend

Teknologi:
- Node.js.
- Express.
- Prisma ORM.
- PostgreSQL.
- Middleware autentikasi dan otorisasi.
- Validasi input.
- Layanan email.
- Logging dan penanganan error.

Backend menjadi sumber kebenaran untuk akun, peran, event, kuota, pesanan, pembayaran, tiket, dan check-in.

### 8.3 Model Database Awal

Model yang diperkirakan diperlukan:
- User.
- OrganizerProfile, jika informasi penyelenggara dipisahkan dari akun.
- Event.
- TicketType.
- Order.
- OrderItem.
- Payment.
- Ticket.
- EventStaff atau tabel pengelolaan undangan dan keanggotaan staf.
- CheckIn.
- SupportReport.
- SupportReportActivity.
- AuditLog.

Relasi, indeks, constraint, dan field final ditentukan dalam dokumen desain database sebelum implementasi.

### 8.4 Kontrak API Awal

Contoh endpoint yang diperkirakan:

**Autentikasi**
- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/logout`

**Event**
- `GET /events`
- `GET /events/:id`
- `POST /events`
- `PATCH /events/:id`
- `POST /events/:id/submit-review`
- `POST /admin/events/:id/approve`
- `POST /admin/events/:id/reject`

**Pesanan dan pembayaran**
- `POST /events/:id/orders`
- `GET /orders/:id`
- `POST /orders/:id/payment-simulation`
- `GET /orders/:id/payment-status`

**Tiket dan check-in**
- `GET /me/tickets`
- `GET /tickets/:id`
- `POST /tickets/validate`
- `POST /tickets/check-in`
- Endpoint sinkronisasi check-in offline yang dirancang terpisah.

**Staf**
- Endpoint membuat undangan.
- Endpoint menerima undangan.
- Endpoint mencabut akses staf.

**Laporan kendala**
- `POST /support/reports`
- `GET /support/reports/:token`
- `GET /admin/support/reports`
- `PATCH /admin/support/reports/:id`

Endpoint di atas adalah rancangan awal, bukan kontrak API final. Payload, autentikasi, otorisasi, format error, dan validasi harus ditentukan sebelum mobile dan backend dikerjakan secara paralel.

---

## 9. Persyaratan Nonfungsional

### 9.1 Keamanan
- Kata sandi disimpan menggunakan hashing yang sesuai.
- Endpoint privat dilindungi autentikasi dan otorisasi.
- Semua pemeriksaan kepemilikan event dilakukan di backend.
- Token tiket dan token akses laporan harus sulit ditebak.
- QR Code tidak memuat informasi pribadi berlebihan.
- Data sensitif tidak disimpan di Shared Preferences tanpa perlindungan yang sesuai.
- Rahasia aplikasi disimpan melalui konfigurasi lingkungan.
- Akses dan perubahan penting dicatat dalam audit log.

### 9.2 Konsistensi Data
- Kuota tidak boleh terjual melebihi aturan kapasitas.
- Pembayaran yang diproses berulang tidak menerbitkan tiket berulang.
- Check-in online harus aman terhadap pemindaian bersamaan.
- Proses sinkronisasi offline harus memiliki penanganan konflik yang jelas.

### 9.3 Kegunaan
- Antarmuka responsif.
- Formulir memiliki validasi dan pesan error yang mudah dipahami.
- Status pesanan, tiket, dan laporan terlihat jelas.
- Halaman publik dapat diakses melalui URL langsung.
- Navigasi menyesuaikan peran pengguna.

### 9.4 Keandalan
- Error API memiliki format konsisten.
- Kegagalan email tidak merusak status penerbitan tiket.
- Kegagalan jaringan ditampilkan dengan jelas.
- Operasi penting memiliki log yang memadai untuk penelusuran masalah.

### 9.5 Privasi
- Hanya mengumpulkan data peserta yang diperlukan.
- Membatasi akses ke data peserta sesuai peran.
- Menetapkan kebijakan penyimpanan dan penghapusan data.
- Menyediakan informasi kebijakan privasi dan ketentuan layanan sebelum peluncuran publik.

---

## 10. Strategi Pengujian

### 10.1 Pengujian Fungsional
- Registrasi dan login.
- Pembuatan dan moderasi event.
- Pengaturan kategori dan kuota.
- Pemesanan beberapa tiket.
- Simulasi pembayaran berhasil, gagal, dan kedaluwarsa.
- Penerbitan tiket dan pengiriman email.
- Validasi QR dan check-in.
- Penerimaan undangan serta pembatasan akses staf.
- Pengiriman dan penanganan laporan kendala.

### 10.2 Pengujian Keamanan
- Pengguna tidak dapat mengakses event milik penyelenggara lain.
- Staf tidak dapat melakukan tindakan di luar izin.
- Tiket yang sudah digunakan tidak dapat check-in kembali secara online.
- Pembayaran tidak dapat dinyatakan berhasil hanya dengan memodifikasi permintaan klien.
- Token tiket dan tautan laporan tidak mudah ditebak.

### 10.3 Pengujian Offline
- Scanner kehilangan koneksi.
- Data validasi lokal tidak tersedia atau kedaluwarsa.
- Check-in lokal disinkronkan kembali.
- Tiket yang sama digunakan pada lebih dari satu perangkat.
- Konflik ditampilkan dan dicatat tanpa menyatakan semua check-in offline telah terverifikasi.

### 10.4 Pengujian Platform
- Browser desktop.
- Browser mobile.
- Android dengan kamera yang didukung.
- URL event dan e-ticket dibuka langsung dari tautan.
- Tampilan formulir dan dashboard pada ukuran layar berbeda.

---

## 11. Pembagian Tugas Tim

Pembagian berikut adalah usulan berdasarkan tiga orang yang mengembangkan satu sistem bersama.

### Anggota 1 — mobile dan Pengalaman Pengguna
- Struktur Flutter dan routing.
- Halaman publik.
- Detail event dan registrasi.
- Halaman peserta dan e-ticket.
- Dashboard penyelenggara.
- Integrasi API untuk halaman yang menjadi tanggung jawabnya.

### Anggota 2 — Backend dan Database
- Struktur server Node.js + Express.
- Skema PostgreSQL dan Prisma.
- Autentikasi dan otorisasi.
- CRUD event dan moderasi.
- Kategori tiket, pesanan, kuota, dan simulasi pembayaran.
- Penerbitan tiket dan layanan email.
- API laporan kendala.

### Anggota 3 — Scanner, Check-in, dan Pengujian Integrasi
- Integrasi QR scanner.
- Validasi dan check-in.
- Mode offline terbatas dan sinkronisasi.
- Manajemen staf dan izin scanner.
- Riwayat pemindaian.
- Pengujian integrasi serta alur end-to-end.
- Bantuan integrasi mobile dan backend.

### Aturan Kerja Bersama
- Semua anggota menyepakati skema database dan kontrak API sebelum integrasi.
- Setiap anggota menggunakan branch fitur tersendiri.
- Perubahan digabung melalui pull request.
- Jangan mengedit file bersama secara bersamaan tanpa koordinasi.
- Gunakan mock data ketika API belum tersedia.
- Lakukan pengujian bersama pada alur lengkap sebelum demo.

---

## 12. Risiko dan Mitigasi

| Risiko | Mitigasi |
|---|---|
| Lingkup MVP terlalu besar | Prioritaskan alur event sampai check-in; tunda fitur tambahan |
| Overselling tiket | Transaksi database dan strategi konkurensi yang sesuai |
| Pembayaran simulasi disalahgunakan | Verifikasi perubahan status di backend |
| Check-in ganda | Validasi atomik ketika online |
| Konflik scanner offline | Cache terbatas, antrean sinkronisasi, dan penandaan konflik |
| Email tidak terkirim | Simpan status pengiriman dan sediakan pengiriman ulang |
| Kebocoran data peserta | Otorisasi, minimisasi data, dan pembatasan akses |
| Konflik pekerjaan tiga anggota | Kontrak API, branch, dan pull request |
| Biaya layanan belum jelas | Tetapkan aturan sebelum demo model bisnis atau peluncuran publik |

---

## 13. Keputusan yang Belum Final

Bagian ini harus ditinjau sebelum PRD dinyatakan final.

1. **Batas waktu pembayaran:** apakah tetap, misalnya 15 menit, atau dapat dikonfigurasi oleh penyelenggara?
2. **Metode pembayaran simulasi:** diasumsikan Virtual Account saja untuk MVP.
3. **Mode offline:** perlu dipastikan perangkat yang didukung, lama cache, dan strategi konflik.
4. **Biaya layanan:** persentase atau nominal tetap, pihak yang membayar, dan cara perhitungannya.
5. **Kuota tanpa batas:** batas operasional maksimum belum ditentukan.
6. **Pembatalan dan refund:** belum menjadi fitur inti MVP; perlu ditetapkan kebijakannya.
7. **Undangan staf:** mekanisme tautan/email, masa berlaku, dan proses penerimaan harus dirinci.
8. **Ekspor peserta:** CSV diprioritaskan; ekspor Excel menyesuaikan waktu.
9. **PDF e-ticket:** dipertimbangkan setelah halaman tiket dan email berjalan baik.
10. **Hosting:** lokasi deployment mobile, backend, database, dan konfigurasi domain belum ditentukan.
11. **Target waktu:** belum ditetapkan sehingga estimasi sprint baru dapat dibuat setelah prioritas fitur disepakati.
12. **Kebijakan privasi dan layanan:** harus disiapkan sebelum produk digunakan secara publik.

---

## 14. Kriteria Penyelesaian MVP

MVP dapat dinyatakan selesai apabila satu alur pengujian utama berhasil:

1. Penyelenggara membuat event dan mengajukannya.
2. Admin menyetujui event.
3. Event tersedia melalui URL publik.
4. Peserta memilih kategori dan memesan tiket.
5. Peserta menyelesaikan simulasi pembayaran.
6. Backend mengonfirmasi pembayaran dan menerbitkan tiket unik.
7. Peserta membuka e-ticket dan menerima email.
8. Staf yang berwenang memindai tiket.
9. Sistem mencatat check-in dan mencegah penggunaan ulang ketika online.
10. Peserta dapat mengirim laporan kendala.
11. Admin dapat memproses laporan tersebut.
12. Mode offline menunjukkan status lokal dan menangani sinkronisasi serta konflik sesuai batasan yang telah ditetapkan.

Semua alur wajib diuji pada lingkungan demonstrasi yang disepakati oleh tim.

---

## 15. Catatan Status Dokumen

Dokumen ini merupakan **PRD draf versi 0.1** yang dibangun dari kebutuhan pengguna dan keputusan arsitektur awal.

Dokumen belum menjadi spesifikasi final implementasi. Sebelum coding paralel dimulai, tim perlu menyetujui:
- Aturan bisnis dan status.
- Struktur database.
- Kontrak API.
- Prioritas fitur dan batasan offline.
- Rancangan UI yang lebih terperinci.
- Pembagian pekerjaan dan target iterasi.

Setelah keputusan tersebut disepakati, PRD dapat diperbarui menjadi versi 1.0 dan digunakan sebagai acuan pengembangan.

CREATE OR REPLACE VIEW v_sisa_cuti_pegawai AS
SELECT
    p.ID_Pegawai,
    p.Nama_Pegawai,
    p.Role,
    p.Status_Aktif,
    p.Sisa_Cuti_Tahunan AS Sisa_Cuti,
    COALESCE(SUM(CASE WHEN pc.Status_Pengajuan = 'pending'
                      THEN pc.Durasi_Hari END), 0)    AS Total_Hari_Pending,
    COALESCE(SUM(CASE WHEN pc.Status_Pengajuan = 'disetujui'
                      THEN pc.Durasi_Hari END), 0)    AS Total_Hari_Terpakai
FROM Pegawai p
LEFT JOIN Pengajuan_Cuti pc
       ON pc.ID_Pegawai = p.ID_Pegawai
      AND pc.ID_Jenis IN (SELECT ID_Jenis FROM Jenis_Cuti
                          WHERE Apakah_Potong_Cuti_Tahunan = TRUE)
GROUP BY p.ID_Pegawai, p.Nama_Pegawai, p.Role, p.Status_Aktif, p.Sisa_Cuti_Tahunan;

CREATE OR REPLACE VIEW v_daftar_pengajuan_cuti AS
SELECT
    pc.ID_Pengajuan,
    pc.ID_Pegawai,
    p.Nama_Pegawai,
    p.ID_Atasan,
    at.Nama_Pegawai AS Nama_Atasan,
    jc.Nama_Jenis,
    jc.Apakah_Potong_Cuti_Tahunan,
    pc.Tgl_Mulai,
    pc.Tgl_Selesai,
    pc.Durasi_Hari,
    pc.Status_Pengajuan,
    (SELECT COUNT(*) FROM Approval_Cuti ac
      WHERE ac.ID_Pengajuan = pc.ID_Pengajuan
        AND ac.Status_Approval = 'disetujui') AS Jumlah_Approval_Masuk,
    (SELECT COUNT(*) FROM Detail_Libur_Cuti dl
      WHERE dl.ID_Pengajuan = pc.ID_Pengajuan) AS Jumlah_Hari_Libur_Dalam_Rentang
FROM Pengajuan_Cuti pc
JOIN Pegawai p     ON p.ID_Pegawai = pc.ID_Pegawai
LEFT JOIN Pegawai at ON at.ID_Pegawai = p.ID_Atasan
JOIN Jenis_Cuti jc ON jc.ID_Jenis = pc.ID_Jenis;

CREATE OR REPLACE VIEW v_pengajuan_bawahan_pending AS
SELECT *
FROM v_daftar_pengajuan_cuti
WHERE Status_Pengajuan = 'pending';

CREATE OR REPLACE VIEW v_riwayat_kuota_cuti AS
SELECT
    rk.ID_Riwayat,
    rk.ID_Pegawai,
    p.Nama_Pegawai,
    rk.Tgl_Perubahan,
    rk.Perubahan_Saldo,
    SUM(rk.Perubahan_Saldo) OVER (
        PARTITION BY rk.ID_Pegawai
        ORDER BY rk.Tgl_Perubahan, rk.ID_Riwayat
    ) AS Saldo_Berjalan,
    rk.Keterangan
FROM Riwayat_Kuota_Cuti rk
JOIN Pegawai p ON p.ID_Pegawai = rk.ID_Pegawai;

CREATE OR REPLACE VIEW v_statistik_cuti_tahunan AS
SELECT
    pc.ID_Pegawai,
    p.Nama_Pegawai,
    YEAR(pc.Tgl_Mulai) AS Tahun,
    COUNT(*)                                                    AS Jumlah_Pengajuan,
    SUM(pc.Status_Pengajuan = 'disetujui')                      AS Jumlah_Disetujui,
    SUM(pc.Status_Pengajuan = 'ditolak')                        AS Jumlah_Ditolak,
    SUM(pc.Status_Pengajuan = 'dibatalkan')                     AS Jumlah_Dibatalkan,
    COALESCE(SUM(CASE WHEN pc.Status_Pengajuan = 'disetujui'
                      THEN pc.Durasi_Hari END), 0)              AS Total_Hari_Disetujui
FROM Pengajuan_Cuti pc
JOIN Pegawai p ON p.ID_Pegawai = pc.ID_Pegawai
GROUP BY pc.ID_Pegawai, p.Nama_Pegawai, YEAR(pc.Tgl_Mulai);


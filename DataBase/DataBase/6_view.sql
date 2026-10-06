DROP VIEW IF EXISTS v_sisa_cuti_pegawai;
CREATE VIEW v_sisa_cuti_pegawai AS
SELECT
    ID_Pegawai,
    Nama_Pegawai,
    Sisa_Cuti_Tahunan AS Sisa_Cuti
FROM Pegawai
WHERE Status_Aktif = TRUE;


DROP VIEW IF EXISTS v_daftar_pengajuan_cuti;
CREATE VIEW v_daftar_pengajuan_cuti AS
SELECT
    pc.ID_Pengajuan,
    pc.ID_Pegawai,
    p.Nama_Pegawai,
    jc.Nama_Jenis,
    pc.Tgl_Mulai,
    pc.Tgl_Selesai,
    pc.Durasi_Hari,
    pc.Status_Pengajuan
FROM Pengajuan_Cuti pc
JOIN Pegawai p
    ON pc.ID_Pegawai = p.ID_Pegawai
JOIN Jenis_Cuti jc
    ON pc.ID_Jenis = jc.ID_Jenis;

SELECT
    ID_Pengajuan,
    ID_Pegawai,
    Nama_Pegawai,
    Nama_Jenis,
    Tgl_Mulai,
    Tgl_Selesai,
    Durasi_Hari,
    Status_Pengajuan
FROM v_daftar_pengajuan_cuti
WHERE Status_Pengajuan = 'pending';






-- ============================================================
-- Procedure pegawai pengajuan cuti
-- ============================================================
DELIMITER $$

CREATE PROCEDURE sp_buat_pengajuan_cuti(
    p_id_pegawai  INT,
    p_id_jenis    INT,
    p_tgl_mulai   DATE,
    p_tgl_selesai DATE
)
BEGIN
    DECLARE v_durasi INT;
    DECLARE v_potong BOOLEAN;
    DECLARE v_sisa INT;
    DECLARE v_error_msg VARCHAR(255) DEFAULT '';

    IF NOT EXISTS (
        SELECT 1 FROM Pegawai WHERE ID_Pegawai = p_id_pegawai AND Status_Aktif = TRUE
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pegawai tidak aktif atau tidak ditemukan.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM Jenis_Cuti WHERE ID_Jenis = p_id_jenis) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Jenis cuti tidak valid.';
    END IF;

    IF p_tgl_mulai > p_tgl_selesai THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tanggal mulai harus sebelum tanggal selesai.';
    END IF;

    SET v_durasi = fn_hitung_hari_kerja(p_tgl_mulai, p_tgl_selesai);

    IF v_durasi = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tidak ada hari kerja dalam rentang tanggal tersebut.';
    END IF;

    -- Cek apakah ada pengajuan pending di rentang tanggal yang sama
    IF EXISTS (
        SELECT 1 FROM Pengajuan_Cuti
        WHERE ID_Pegawai = p_id_pegawai
          AND Status_Pengajuan = 'pending'
          AND (
              (p_tgl_mulai BETWEEN Tgl_Mulai AND Tgl_Selesai) OR
              (p_tgl_selesai BETWEEN Tgl_Mulai AND Tgl_Selesai) OR
              (Tgl_Mulai BETWEEN p_tgl_mulai AND p_tgl_selesai)
          )
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Sudah ada pengajuan cuti pending di rentang tanggal tersebut.';
    END IF;

    -- Insert pengajuan
    INSERT INTO Pengajuan_Cuti (ID_Pegawai, ID_Jenis, Tgl_Mulai, Tgl_Selesai, Durasi_Hari, Status_Pengajuan)
    VALUES (p_id_pegawai, p_id_jenis, p_tgl_mulai, p_tgl_selesai, v_durasi, 'pending');

    SET @v_id_pengajuan = LAST_INSERT_ID();

    -- Insert detail libur (weekend & libur nasional dalam rentang)
    INSERT INTO Detail_Libur_Cuti (ID_Pengajuan, Tanggal_Libur)
    SELECT @v_id_pengajuan, v_tgl
    FROM (
        SELECT DATE_ADD(p_tgl_mulai, INTERVAL seq DAY) AS v_tgl
        FROM (
            SELECT @row := @row + 1 AS seq
            FROM information_schema.columns, (SELECT @row := -1) r
            LIMIT DATEDIFF(p_tgl_selesai, p_tgl_mulai) + 1
        ) t
    ) dates
    WHERE DAYOFWEEK(v_tgl) IN (1, 7)
       OR EXISTS (SELECT 1 FROM Libur_Nasional WHERE Tanggal_Libur = v_tgl);
END$$

DELIMITER ;

-- ============================================================
-- Procedure Tambah pegawai
-- =============================================================
DELIMITER $$

CREATE PROCEDURE sp_tambah_pegawai_baru(
    p_nama_pegawai   VARCHAR(150),
    p_id_atasan      INT,
    p_role           ENUM('pegawai','hrd','manajer'),
    p_sisa_cuti      INT
)
BEGIN
    DECLARE v_error_msg VARCHAR(255) DEFAULT '';

    IF p_id_atasan IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM Pegawai WHERE ID_Pegawai = p_id_atasan) THEN
            SET v_error_msg = 'ID Atasan tidak ditemukan.';
        END IF;
    END IF;

    IF v_error_msg <> '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END IF;

    INSERT INTO Pegawai (Nama_Pegawai, ID_Atasan, Role, Sisa_Cuti_Tahunan, Status_Aktif)
    VALUES (p_nama_pegawai, p_id_atasan, p_role, p_sisa_cuti, TRUE);

    INSERT INTO Riwayat_Kuota_Cuti (ID_Pegawai, Perubahan_Saldo, Keterangan)
    VALUES (LAST_INSERT_ID(), p_sisa_cuti, 'Kuota awal saat pendaftaran pegawai baru');
END$$

DELIMITER ;
-- =======================================================
--
-- =======================================================
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_lihat_pengajuan_bawahan$$

CREATE PROCEDURE sp_lihat_pengajuan_bawahan(
    IN p_id_atasan INT
)
BEGIN

    IF NOT EXISTS (
        SELECT 1
        FROM Pegawai
        WHERE ID_Pegawai = p_id_atasan
          AND Role = 'manajer'
          AND Status_Aktif = TRUE
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Manajer tidak ditemukan atau tidak aktif.';
    END IF;

    SELECT
        pc.ID_Pengajuan,
        p.ID_Pegawai,
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
        ON pc.ID_Jenis = jc.ID_Jenis
    WHERE p.ID_Atasan = p_id_atasan
    ORDER BY pc.ID_Pengajuan DESC;

END$$

DELIMITER ;
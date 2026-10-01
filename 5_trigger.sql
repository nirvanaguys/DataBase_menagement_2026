DELIMITER $$
DROP TRIGGER IF EXISTS trg_pengajuan_before_insert$$
CREATE TRIGGER trg_pengajuan_before_insert
BEFORE INSERT ON Pengajuan_Cuti
FOR EACH ROW
BEGIN
    IF NEW.Tgl_Mulai > NEW.Tgl_Selesai THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Tanggal mulai tidak boleh setelah tanggal selesai.';
    END IF;

    SET NEW.Durasi_Hari = fn_hitung_hari_kerja(NEW.Tgl_Mulai, NEW.Tgl_Selesai);

    IF NEW.Durasi_Hari = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Rentang tanggal tidak memiliki hari kerja.';
    END IF;
END$$
DELIMITER ;

DELIMITER $$
DROP TRIGGER IF EXISTS trg_pengajuan_after_update$$
CREATE TRIGGER trg_pengajuan_after_update
AFTER UPDATE ON Pengajuan_Cuti
FOR EACH ROW
BEGIN
    DECLARE v_potong BOOLEAN;

    IF OLD.Status_Pengajuan <> NEW.Status_Pengajuan THEN

        SELECT Apakah_Potong_Cuti_Tahunan INTO v_potong
        FROM Jenis_Cuti WHERE ID_Jenis = NEW.ID_Jenis;

        -- pending -> disetujui : POTONG kuota
        IF NEW.Status_Pengajuan = 'disetujui' AND v_potong = TRUE THEN
            UPDATE Pegawai
            SET Sisa_Cuti_Tahunan = Sisa_Cuti_Tahunan - NEW.Durasi_Hari
            WHERE ID_Pegawai = NEW.ID_Pegawai;

            INSERT INTO Riwayat_Kuota_Cuti (ID_Pegawai, Perubahan_Saldo, Keterangan)
            VALUES (NEW.ID_Pegawai, -NEW.Durasi_Hari,
                    CONCAT('Kuota dipotong - pengajuan #', NEW.ID_Pengajuan, ' disetujui'));
        END IF;

        -- disetujui -> dibatalkan/ditolak : KEMBALIKAN kuota (defensif)
        IF OLD.Status_Pengajuan = 'disetujui'
           AND NEW.Status_Pengajuan IN ('dibatalkan','ditolak')
           AND v_potong = TRUE THEN
            UPDATE Pegawai
            SET Sisa_Cuti_Tahunan = Sisa_Cuti_Tahunan + NEW.Durasi_Hari
            WHERE ID_Pegawai = NEW.ID_Pegawai;

            INSERT INTO Riwayat_Kuota_Cuti (ID_Pegawai, Perubahan_Saldo, Keterangan)
            VALUES (NEW.ID_Pegawai, NEW.Durasi_Hari,
                    CONCAT('Kuota dikembalikan - pengajuan #', NEW.ID_Pengajuan, ' batal setelah disetujui'));
        END IF;
    END IF;
END$$
DELIMITER ;

DELIMITER $$
DROP TRIGGER IF EXISTS trg_pegawai_before_update$$
CREATE TRIGGER trg_pegawai_before_update
BEFORE UPDATE ON Pegawai
FOR EACH ROW
BEGIN
    IF NEW.Sisa_Cuti_Tahunan < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Sisa cuti tidak boleh negatif.';
    END IF;
END$$
DELIMITER ;

DELIMITER $$
DROP TRIGGER IF EXISTS trg_pegawai_after_update$$
CREATE TRIGGER trg_pegawai_after_update
AFTER UPDATE ON Pegawai
FOR EACH ROW
BEGIN
    IF OLD.Status_Aktif = TRUE AND NEW.Status_Aktif = FALSE THEN
        UPDATE Pengajuan_Cuti
        SET Status_Pengajuan = 'dibatalkan'
        WHERE ID_Pegawai = NEW.ID_Pegawai
          AND Status_Pengajuan = 'pending';
    END IF;
END$$
DELIMITER ;

DELIMITER $$
DROP TRIGGER IF EXISTS trg_approval_before_insert$$
CREATE TRIGGER trg_approval_before_insert
BEFORE INSERT ON Approval_Cuti
FOR EACH ROW
BEGIN
    DECLARE v_pengaju INT;

    SELECT ID_Pegawai INTO v_pengaju
    FROM Pengajuan_Cuti
    WHERE ID_Pengajuan = NEW.ID_Pengajuan;

    IF fn_is_atasan(NEW.ID_Approver, v_pengaju) = FALSE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Approver bukan atasan langsung pengaju.';
    END IF;

    IF EXISTS (SELECT 1 FROM Approval_Cuti
               WHERE ID_Pengajuan = NEW.ID_Pengajuan
                 AND Level_Approval = NEW.Level_Approval) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Level approval ini sudah diproses sebelumnya.';
    END IF;
END$$
DELIMITER ;
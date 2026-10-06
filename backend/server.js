const express = require('express');
const mysql = require('mysql2/promise');

const app = express();

app.use(express.json());

const db = mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: '123456',
    database: 'sistem_cuti'
});

app.get('/', (req, res) => {
    res.json({
        message: 'API Sistem Cuti berjalan'
    });
});

app.get('/api/test-db', async (req, res) => {
    try {
        const [rows] = await db.query('SELECT DATABASE() AS nama_database');

        res.json({
            success: true,
            database: rows[0].nama_database
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
});

app.get('/api/cuti/sisa', async (req, res) => {
    try {
        const [rows] = await db.query(`
            SELECT
                ID_Pegawai,
                Nama_Pegawai,
                Sisa_Cuti
            FROM v_sisa_cuti_pegawai
        `);

        res.json({
            success: true,
            data: rows
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
});

app.get('/api/cuti/sisa/:id', async (req, res) => {
    try {
        const idPegawai = req.params.id;

        const [rows] = await db.query(
            `SELECT fn_sisa_cuti(?) AS Sisa_Cuti`,
            [idPegawai]
        );

        res.json({
            success: true,
            ID_Pegawai: Number(idPegawai),
            Sisa_Cuti: rows[0].Sisa_Cuti
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
});

app.post('/api/cuti', async (req, res) => {
    try {
        const {
            id_pegawai,
            id_jenis,
            tgl_mulai,
            tgl_selesai
        } = req.body;

        const [result] = await db.query(
            `CALL sp_buat_pengajuan_cuti(?, ?, ?, ?)`,
            [
                id_pegawai,
                id_jenis,
                tgl_mulai,
                tgl_selesai
            ]
        );

        res.json({
            success: true,
            message: 'Pengajuan cuti berhasil dibuat',
            data: result
        });
    } catch (error) {
        res.status(400).json({
            success: false,
            message: error.message
        });
    }
});

app.get('/api/cuti', async (req, res) => {
    try {
        const [rows] = await db.query(`
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
        `);

        res.json({
            success: true,
            data: rows
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
});

app.post('/api/cuti/approve', async (req, res) => {
    try {
        const {
            id_pengajuan,
            id_approver,
            catatan
        } = req.body;

        const [result] = await db.query(
            `CALL sp_setujui_pengajuan_cuti(?, ?, ?)`,
            [
                id_pengajuan,
                id_approver,
                catatan
            ]
        );

        res.json({
            success: true,
            message: 'Pengajuan cuti berhasil disetujui',
            data: result
        });
    } catch (error) {
        res.status(400).json({
            success: false,
            message: error.message
        });
    }
});

app.get('/api/cuti/riwayat/:id', async (req, res) => {
    try {
        const idPegawai = req.params.id;

        const [rows] = await db.query(`
            SELECT
                ID_Riwayat,
                ID_Pegawai,
                Perubahan_Saldo,
                Keterangan
            FROM v_riwayat_kuota_cuti
            WHERE ID_Pegawai = ?
        `, [idPegawai]);

        res.json({
            success: true,
            data: rows
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
});

app.listen(3000, () => {
    console.log('Server berjalan di http://localhost:3000');
});
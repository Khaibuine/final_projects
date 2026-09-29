-- ============================================================
-- 03_views_seed_mysql.sql
-- Views + dữ liệu danh mục tối thiểu
-- ============================================================

USE quanlydetai;

-- Hai loại điểm bắt buộc theo thiết kế hiện tại.
INSERT INTO LOAI_DIEM(Ma_Loai_Diem, Ten_Loai_Diem)
VALUES
    ('GVPB', 'Điểm phản biện'),
    ('HD',   'Điểm hội đồng')
ON DUPLICATE KEY UPDATE
    Ten_Loai_Diem = VALUES(Ten_Loai_Diem);

-- ============================================================
-- View: báo cáo mới nhất của mỗi nhóm.
-- ============================================================
CREATE OR REPLACE VIEW VW_BAO_CAO_MOI_NHAT AS
SELECT b.*
FROM BAO_CAO b
JOIN (
    SELECT Ma_Nhom, MAX(Lan_Nop) AS Max_Lan_Nop
    FROM BAO_CAO
    GROUP BY Ma_Nhom
) x
  ON x.Ma_Nhom = b.Ma_Nhom
 AND x.Max_Lan_Nop = b.Lan_Nop;

-- ============================================================
-- View: trung bình theo từng loại điểm.
-- ============================================================
CREATE OR REPLACE VIEW VW_DIEM_TRUNG_BINH_THEO_LOAI AS
SELECT
    Ma_De_Tai,
    Ma_Loai_Diem,
    ROUND(AVG(Diem), 2) AS Diem_Trung_Binh
FROM DIEM_THANH_PHAN
GROUP BY Ma_De_Tai, Ma_Loai_Diem;

-- ============================================================
-- View: chỉ các kết quả đã công bố.
-- Backend SV nên đọc từ view này thay vì bảng KET_QUA_DE_TAI trực tiếp.
-- ============================================================
CREATE OR REPLACE VIEW VW_KET_QUA_DA_CONG_BO AS
SELECT
    k.Ma_De_Tai,
    d.Ten_De_Tai,
    k.Diem_Cuoi,
    k.Nhan_Xet_Tong_Hop,
    k.Ket_Qua,
    k.Ma_GV_Tong_Hop,
    k.Ngay_Tong_Hop,
    k.Ngay_Cong_Bo
FROM KET_QUA_DE_TAI k
JOIN DE_TAI d ON d.Ma_De_Tai = k.Ma_De_Tai
WHERE k.Trang_Thai_Cong_Bo = 'DaCongBo';

-- ============================================================
-- View: danh sách đề tài SV được phép nhìn để chọn.
-- Lọc thêm theo thời gian ở application hoặc query tùy đợt.
-- ============================================================
CREATE OR REPLACE VIEW VW_DE_TAI_DA_CONG_BO AS
SELECT
    d.Ma_De_Tai,
    d.Ten_De_Tai,
    d.Ma_Bo_Mon,
    d.Noi_Dung,
    d.Ma_Dot,
    d.Ma_GV_Dang_Ky,
    d.Ngay_Dang_Ky
FROM DE_TAI d
LEFT JOIN NHOM n ON n.Ma_De_Tai = d.Ma_De_Tai
WHERE d.Trang_Thai = 'DaCongBo'
  AND n.Ma_De_Tai IS NULL;

-- ============================================================
-- END 03_views_seed_mysql.sql
-- ============================================================

-- ============================================================
-- 02_logic_mysql.sql
-- Trigger + stored procedure nghiệp vụ
-- MySQL 8.0.16+
-- ============================================================

USE quanlydetai;

DELIMITER $$

-- ============================================================
-- Helper: validate quyền nhập/sửa điểm.
-- ============================================================
DROP PROCEDURE IF EXISTS sp_validate_diem$$
CREATE PROCEDURE sp_validate_diem(
    IN p_Ma_GV VARCHAR(20),
    IN p_Ma_De_Tai VARCHAR(20),
    IN p_Ma_Loai_Diem VARCHAR(20)
)
BEGIN
    DECLARE v_Ma_Dot VARCHAR(20);
    DECLARE v_Loai VARCHAR(20);
    DECLARE v_Deadline DATETIME;

    -- Khóa đề tài để serialize thao tác điểm <-> tổng hợp kết quả.
    SELECT Ma_Dot
      INTO v_Ma_Dot
      FROM DE_TAI
     WHERE Ma_De_Tai = p_Ma_De_Tai
     FOR UPDATE;

    IF v_Ma_Dot IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Đề tài không tồn tại.';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM KET_QUA_DE_TAI
         WHERE Ma_De_Tai = p_Ma_De_Tai
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Đề tài đã tổng hợp kết quả; điểm thành phần đã bị khóa.';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM GVHD_DETAI
         WHERE Ma_GV = p_Ma_GV
           AND Ma_De_Tai = p_Ma_De_Tai
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GVHD không được chấm đề tài mình hướng dẫn.';
    END IF;

    IF p_Ma_Loai_Diem = 'GVPB' THEN

        IF NOT EXISTS (
            SELECT 1
              FROM GVPB_DETAI
             WHERE Ma_GV = p_Ma_GV
               AND Ma_De_Tai = p_Ma_De_Tai
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Giảng viên không phải GVPB được phân công cho đề tài.';
        END IF;

        SELECT Loai, Deadline_GVPB_Nop_Diem
          INTO v_Loai, v_Deadline
          FROM DOT_DANG_KY
         WHERE Ma_Dot = v_Ma_Dot;

        IF v_Loai IN ('TLCN','KLTN')
           AND CURRENT_TIMESTAMP > v_Deadline THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Đã quá hạn nộp điểm GVPB.';
        END IF;

    ELSEIF p_Ma_Loai_Diem = 'HD' THEN

        IF NOT EXISTS (
            SELECT 1
              FROM HOI_DONG_DE_TAI hdt
              JOIN HOI_DONG hd
                ON hd.Ma_HD = hdt.Ma_HD
              JOIN THANHVIEN_HOIDONG tv
                ON tv.Ma_HD = hd.Ma_HD
               AND tv.Ma_GV = p_Ma_GV
             WHERE hdt.Ma_De_Tai = p_Ma_De_Tai
               AND hd.Trang_Thai = 'DaChot'
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Giảng viên không thuộc hội đồng đã chốt đang chấm đề tài.';
        END IF;

    ELSE
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Loại điểm không hợp lệ. Chỉ hỗ trợ GVPB hoặc HD.';
    END IF;
END$$

-- ============================================================
-- DE_TAI: ngày đăng ký phải nằm trong giai đoạn GV.
-- ============================================================
DROP TRIGGER IF EXISTS trg_DE_TAI_bi$$
CREATE TRIGGER trg_DE_TAI_bi
BEFORE INSERT ON DE_TAI
FOR EACH ROW
BEGIN
    DECLARE v_Begin DATETIME;
    DECLARE v_End DATETIME;

    SELECT Begin_GV, End_GV
      INTO v_Begin, v_End
      FROM DOT_DANG_KY
     WHERE Ma_Dot = NEW.Ma_Dot;

    IF NEW.Ngay_Dang_Ky < v_Begin OR NEW.Ngay_Dang_Ky > v_End THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ngay_Dang_Ky phải nằm trong Begin_GV - End_GV.';
    END IF;
END$$

-- DE_TAI state machine + gate công bố + Ma_Dot immutable.
DROP TRIGGER IF EXISTS trg_DE_TAI_bu$$
CREATE TRIGGER trg_DE_TAI_bu
BEFORE UPDATE ON DE_TAI
FOR EACH ROW
BEGIN
    DECLARE v_SoGVHD INT DEFAULT 0;

    IF NEW.Ma_Dot <> OLD.Ma_Dot
       AND OLD.Trang_Thai <> 'Nhap' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không được đổi Ma_Dot sau khi đề tài rời trạng thái Nhap.';
    END IF;

    IF NEW.Trang_Thai <> OLD.Trang_Thai THEN
        IF NOT (
               (OLD.Trang_Thai = 'Nhap'         AND NEW.Trang_Thai IN ('DaCongBo','Huy'))
            OR (OLD.Trang_Thai = 'DaCongBo'     AND NEW.Trang_Thai IN ('DangThucHien','Huy'))
            OR (OLD.Trang_Thai = 'DangThucHien' AND NEW.Trang_Thai = 'HoanThanh')
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Chuyển trạng thái đề tài không hợp lệ.';
        END IF;

        IF OLD.Trang_Thai = 'Nhap' AND NEW.Trang_Thai = 'DaCongBo' THEN
            SELECT COUNT(*)
              INTO v_SoGVHD
              FROM GVHD_DETAI
             WHERE Ma_De_Tai = NEW.Ma_De_Tai;

            IF v_SoGVHD < 1 OR v_SoGVHD > 2 THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'Chỉ được công bố đề tài khi có từ 1 đến 2 GVHD.';
            END IF;
        END IF;

        IF OLD.Trang_Thai = 'DaCongBo'
           AND NEW.Trang_Thai = 'DangThucHien'
           AND NOT EXISTS (
                SELECT 1 FROM NHOM WHERE Ma_De_Tai = NEW.Ma_De_Tai
           ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Đề tài phải có nhóm đăng ký trước khi chuyển sang DangThucHien.';
        END IF;

        IF NEW.Trang_Thai = 'Huy'
           AND EXISTS (
                SELECT 1 FROM NHOM WHERE Ma_De_Tai = NEW.Ma_De_Tai
           ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Không thể hủy đề tài đã có nhóm đăng ký.';
        END IF;
    END IF;
END$$

-- ============================================================
-- GVHD_DETAI:
-- - tối đa 2
-- - chỉ sửa khi DE_TAI còn Nhap
-- - không trùng GVPB / thành viên hội đồng chấm đề tài.
-- ============================================================
DROP TRIGGER IF EXISTS trg_GVHD_DETAI_bi$$
CREATE TRIGGER trg_GVHD_DETAI_bi
BEFORE INSERT ON GVHD_DETAI
FOR EACH ROW
BEGIN
    DECLARE v_TrangThai VARCHAR(30);
    DECLARE v_Count INT DEFAULT 0;

    SELECT Trang_Thai
      INTO v_TrangThai
      FROM DE_TAI
     WHERE Ma_De_Tai = NEW.Ma_De_Tai
     FOR UPDATE;

    IF v_TrangThai <> 'Nhap' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GVHD bị khóa sau khi đề tài đã công bố.';
    END IF;

    SELECT COUNT(*)
      INTO v_Count
      FROM GVHD_DETAI
     WHERE Ma_De_Tai = NEW.Ma_De_Tai;

    IF v_Count >= 2 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Mỗi đề tài tối đa 2 GVHD.';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM GVPB_DETAI
         WHERE Ma_GV = NEW.Ma_GV
           AND Ma_De_Tai = NEW.Ma_De_Tai
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GVHD không được đồng thời là GVPB cùng đề tài.';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM HOI_DONG_DE_TAI hdt
          JOIN THANHVIEN_HOIDONG tv ON tv.Ma_HD = hdt.Ma_HD
         WHERE hdt.Ma_De_Tai = NEW.Ma_De_Tai
           AND tv.Ma_GV = NEW.Ma_GV
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GVHD không được là thành viên hội đồng chấm cùng đề tài.';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_GVHD_DETAI_bu$$
CREATE TRIGGER trg_GVHD_DETAI_bu
BEFORE UPDATE ON GVHD_DETAI
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Không cập nhật trực tiếp GVHD_DETAI; hãy xóa/thêm lại khi đề tài còn Nhap.';
END$$

DROP TRIGGER IF EXISTS trg_GVHD_DETAI_bd$$
CREATE TRIGGER trg_GVHD_DETAI_bd
BEFORE DELETE ON GVHD_DETAI
FOR EACH ROW
BEGIN
    DECLARE v_TrangThai VARCHAR(30);

    SELECT Trang_Thai
      INTO v_TrangThai
      FROM DE_TAI
     WHERE Ma_De_Tai = OLD.Ma_De_Tai
     FOR UPDATE;

    IF v_TrangThai <> 'Nhap' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không được xóa GVHD sau khi đề tài đã công bố.';
    END IF;
END$$

-- ============================================================
-- GVPB_DETAI:
-- - không trùng GVHD
-- - khóa mọi UPDATE/DELETE sau khi có điểm GVPB hoặc kết quả.
-- ============================================================
DROP TRIGGER IF EXISTS trg_GVPB_DETAI_bi$$
CREATE TRIGGER trg_GVPB_DETAI_bi
BEFORE INSERT ON GVPB_DETAI
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
          FROM GVHD_DETAI
         WHERE Ma_GV = NEW.Ma_GV
           AND Ma_De_Tai = NEW.Ma_De_Tai
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GVPB không được trùng GVHD của cùng đề tài.';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_GVPB_DETAI_bu$$
CREATE TRIGGER trg_GVPB_DETAI_bu
BEFORE UPDATE ON GVPB_DETAI
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
          FROM DIEM_THANH_PHAN
         WHERE Ma_De_Tai = OLD.Ma_De_Tai
           AND Ma_Loai_Diem = 'GVPB'
    ) OR EXISTS (
        SELECT 1
          FROM KET_QUA_DE_TAI
         WHERE Ma_De_Tai = OLD.Ma_De_Tai
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GVPB đã có điểm/kết quả nên phân công đã bị khóa.';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM GVHD_DETAI
         WHERE Ma_GV = NEW.Ma_GV
           AND Ma_De_Tai = NEW.Ma_De_Tai
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'GVPB không được trùng GVHD của cùng đề tài.';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_GVPB_DETAI_bd$$
CREATE TRIGGER trg_GVPB_DETAI_bd
BEFORE DELETE ON GVPB_DETAI
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
          FROM DIEM_THANH_PHAN
         WHERE Ma_De_Tai = OLD.Ma_De_Tai
           AND Ma_Loai_Diem = 'GVPB'
    ) OR EXISTS (
        SELECT 1
          FROM KET_QUA_DE_TAI
         WHERE Ma_De_Tai = OLD.Ma_De_Tai
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không được xóa GVPB sau khi đã có điểm/kết quả.';
    END IF;
END$$

-- ============================================================
-- NHOM:
-- - tạo nhóm trước, chọn đề tài sau
-- - khi chọn: đề tài DaCongBo, đúng thời gian SV, 1-3 SV, đúng 1 trưởng nhóm
-- - không đổi đề tài sau khi đã chọn.
-- ============================================================
DROP TRIGGER IF EXISTS trg_NHOM_bi$$
CREATE TRIGGER trg_NHOM_bi
BEFORE INSERT ON NHOM
FOR EACH ROW
BEGIN
    IF NEW.Ma_De_Tai IS NOT NULL OR NEW.Ngay_Chon_De_Tai IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Hãy tạo nhóm trước, thêm thành viên, sau đó UPDATE để chọn đề tài.';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_NHOM_bu$$
CREATE TRIGGER trg_NHOM_bu
BEFORE UPDATE ON NHOM
FOR EACH ROW
BEGIN
    DECLARE v_CountTV INT DEFAULT 0;
    DECLARE v_CountLeader INT DEFAULT 0;
    DECLARE v_TrangThai VARCHAR(30);
    DECLARE v_BeginSV DATETIME;
    DECLARE v_EndSV DATETIME;

    IF NEW.Ma_Dot <> OLD.Ma_Dot THEN
        IF OLD.Ma_De_Tai IS NOT NULL
           OR EXISTS (
                SELECT 1
                  FROM THANH_VIEN_NHOM
                 WHERE Ma_Nhom = OLD.Ma_Nhom
           ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Không được đổi Ma_Dot khi nhóm đã có thành viên hoặc đã chọn đề tài.';
        END IF;
    END IF;

    IF OLD.Ma_De_Tai IS NOT NULL
       AND NOT (NEW.Ma_De_Tai <=> OLD.Ma_De_Tai) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Nhóm đã chọn đề tài; không được đổi hoặc hủy trực tiếp.';
    END IF;

    IF OLD.Ma_De_Tai IS NULL AND NEW.Ma_De_Tai IS NOT NULL THEN

        SELECT Trang_Thai
          INTO v_TrangThai
          FROM DE_TAI
         WHERE Ma_De_Tai = NEW.Ma_De_Tai
         FOR UPDATE;

        IF v_TrangThai <> 'DaCongBo' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Nhóm chỉ được chọn đề tài đang ở trạng thái DaCongBo.';
        END IF;

        SELECT Begin_SV, End_SV
          INTO v_BeginSV, v_EndSV
          FROM DOT_DANG_KY
         WHERE Ma_Dot = NEW.Ma_Dot;

        IF CURRENT_TIMESTAMP < v_BeginSV
           OR CURRENT_TIMESTAMP > v_EndSV THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Không nằm trong thời gian sinh viên chọn đề tài.';
        END IF;

        SELECT COUNT(*),
               COALESCE(SUM(Vai_Tro = 'Truong_Nhom'), 0)
          INTO v_CountTV, v_CountLeader
          FROM THANH_VIEN_NHOM
         WHERE Ma_Nhom = NEW.Ma_Nhom;

        IF v_CountTV < 1 OR v_CountTV > 3 OR v_CountLeader <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Khi chọn đề tài, nhóm phải có 1-3 SV và đúng 1 trưởng nhóm.';
        END IF;

        SET NEW.Ngay_Chon_De_Tai = CURRENT_TIMESTAMP;
    END IF;

    IF NEW.Ma_De_Tai IS NULL THEN
        SET NEW.Ngay_Chon_De_Tai = NULL;
    ELSEIF OLD.Ma_De_Tai IS NOT NULL THEN
        SET NEW.Ngay_Chon_De_Tai = OLD.Ngay_Chon_De_Tai;
    END IF;
END$$

-- ============================================================
-- THANH_VIEN_NHOM
-- ============================================================
DROP TRIGGER IF EXISTS trg_THANH_VIEN_NHOM_bi$$
CREATE TRIGGER trg_THANH_VIEN_NHOM_bi
BEFORE INSERT ON THANH_VIEN_NHOM
FOR EACH ROW
BEGIN
    DECLARE v_Dot VARCHAR(20);
    DECLARE v_DeTai VARCHAR(20);
    DECLARE v_CountTV INT DEFAULT 0;
    DECLARE v_CountLeader INT DEFAULT 0;

    SELECT Ma_Dot, Ma_De_Tai
      INTO v_Dot, v_DeTai
      FROM NHOM
     WHERE Ma_Nhom = NEW.Ma_Nhom
     FOR UPDATE;

    SELECT COUNT(*)
      INTO v_CountTV
      FROM THANH_VIEN_NHOM
     WHERE Ma_Nhom = NEW.Ma_Nhom;

    IF v_CountTV >= 3 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Một nhóm tối đa 3 sinh viên.';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM THANH_VIEN_NHOM tv
          JOIN NHOM n ON n.Ma_Nhom = tv.Ma_Nhom
         WHERE tv.Ma_SV = NEW.Ma_SV
           AND n.Ma_Dot = v_Dot
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Sinh viên đã thuộc một nhóm khác trong cùng đợt.';
    END IF;

    IF v_DeTai IS NOT NULL THEN
        SELECT COALESCE(SUM(Vai_Tro = 'Truong_Nhom'),0)
          INTO v_CountLeader
          FROM THANH_VIEN_NHOM
         WHERE Ma_Nhom = NEW.Ma_Nhom;

        SET v_CountLeader = v_CountLeader + (NEW.Vai_Tro = 'Truong_Nhom');

        IF v_CountLeader <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Nhóm đã chọn đề tài phải luôn có đúng 1 trưởng nhóm.';
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_THANH_VIEN_NHOM_bu$$
CREATE TRIGGER trg_THANH_VIEN_NHOM_bu
BEFORE UPDATE ON THANH_VIEN_NHOM
FOR EACH ROW
BEGIN
    DECLARE v_DeTai VARCHAR(20);
    DECLARE v_CountLeader INT DEFAULT 0;

    IF NEW.Ma_Nhom <> OLD.Ma_Nhom OR NEW.Ma_SV <> OLD.Ma_SV THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không đổi khóa của thành viên nhóm; hãy DELETE rồi INSERT lại.';
    END IF;

    SELECT Ma_De_Tai
      INTO v_DeTai
      FROM NHOM
     WHERE Ma_Nhom = OLD.Ma_Nhom
     FOR UPDATE;

    IF v_DeTai IS NOT NULL THEN
        SELECT COALESCE(SUM(
            CASE
                WHEN Ma_SV = OLD.Ma_SV THEN 0
                WHEN Vai_Tro = 'Truong_Nhom' THEN 1
                ELSE 0
            END
        ),0)
        INTO v_CountLeader
        FROM THANH_VIEN_NHOM
        WHERE Ma_Nhom = OLD.Ma_Nhom;

        SET v_CountLeader = v_CountLeader + (NEW.Vai_Tro = 'Truong_Nhom');

        IF v_CountLeader <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Nhóm đã chọn đề tài phải luôn có đúng 1 trưởng nhóm.';
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_THANH_VIEN_NHOM_bd$$
CREATE TRIGGER trg_THANH_VIEN_NHOM_bd
BEFORE DELETE ON THANH_VIEN_NHOM
FOR EACH ROW
BEGIN
    DECLARE v_DeTai VARCHAR(20);
    DECLARE v_CountAfter INT DEFAULT 0;
    DECLARE v_LeaderAfter INT DEFAULT 0;

    SELECT Ma_De_Tai
      INTO v_DeTai
      FROM NHOM
     WHERE Ma_Nhom = OLD.Ma_Nhom
     FOR UPDATE;

    IF v_DeTai IS NOT NULL THEN
        SELECT COUNT(*) - 1,
               COALESCE(SUM(Vai_Tro = 'Truong_Nhom'),0)
                 - (OLD.Vai_Tro = 'Truong_Nhom')
          INTO v_CountAfter, v_LeaderAfter
          FROM THANH_VIEN_NHOM
         WHERE Ma_Nhom = OLD.Ma_Nhom;

        IF v_CountAfter < 1 OR v_LeaderAfter <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Không được làm nhóm đã chọn đề tài mất trưởng nhóm/thành viên.';
        END IF;
    END IF;
END$$

-- ============================================================
-- HOI_DONG: state + gate chốt + Ma_Dot immutable khi đã gán đề tài.
-- ============================================================
DROP TRIGGER IF EXISTS trg_HOI_DONG_bu$$
CREATE TRIGGER trg_HOI_DONG_bu
BEFORE UPDATE ON HOI_DONG
FOR EACH ROW
BEGIN
    DECLARE v_CountTV INT DEFAULT 0;
    DECLARE v_CountCT INT DEFAULT 0;
    DECLARE v_CountTK INT DEFAULT 0;

    IF NEW.Ma_Dot <> OLD.Ma_Dot
       AND EXISTS (
            SELECT 1
              FROM HOI_DONG_DE_TAI
             WHERE Ma_HD = OLD.Ma_HD
       ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không được đổi Ma_Dot của hội đồng sau khi đã gán đề tài.';
    END IF;

    IF NEW.Trang_Thai <> OLD.Trang_Thai THEN
        IF NOT (OLD.Trang_Thai = 'DangLap' AND NEW.Trang_Thai = 'DaChot') THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Hội đồng chỉ được chuyển DangLap -> DaChot.';
        END IF;

        SELECT COUNT(*),
               COALESCE(SUM(Vai_Tro = 'ChuTich'),0),
               COALESCE(SUM(Vai_Tro = 'ThuKy'),0)
          INTO v_CountTV, v_CountCT, v_CountTK
          FROM THANHVIEN_HOIDONG
         WHERE Ma_HD = NEW.Ma_HD;

        IF v_CountTV < 3 OR v_CountTV > 5
           OR v_CountCT <> 1 OR v_CountTK <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Hội đồng phải có 3-5 GV, đúng 1 Chủ tịch và 1 Thư ký.';
        END IF;
    END IF;
END$$

-- ============================================================
-- THANHVIEN_HOIDONG
-- ============================================================
DROP TRIGGER IF EXISTS trg_THANHVIEN_HOIDONG_bi$$
CREATE TRIGGER trg_THANHVIEN_HOIDONG_bi
BEFORE INSERT ON THANHVIEN_HOIDONG
FOR EACH ROW
BEGIN
    DECLARE v_TrangThai VARCHAR(20);
    DECLARE v_Count INT DEFAULT 0;

    SELECT Trang_Thai
      INTO v_TrangThai
      FROM HOI_DONG
     WHERE Ma_HD = NEW.Ma_HD
     FOR UPDATE;

    IF v_TrangThai = 'DaChot' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không được thay đổi thành viên hội đồng sau DaChot.';
    END IF;

    SELECT COUNT(*)
      INTO v_Count
      FROM THANHVIEN_HOIDONG
     WHERE Ma_HD = NEW.Ma_HD;

    IF v_Count >= 5 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Một hội đồng tối đa 5 giảng viên.';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM HOI_DONG_DE_TAI hdt
          JOIN GVHD_DETAI g
            ON g.Ma_De_Tai = hdt.Ma_De_Tai
           AND g.Ma_GV = NEW.Ma_GV
         WHERE hdt.Ma_HD = NEW.Ma_HD
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Thành viên hội đồng không được là GVHD của đề tài hội đồng chấm.';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_THANHVIEN_HOIDONG_bu$$
CREATE TRIGGER trg_THANHVIEN_HOIDONG_bu
BEFORE UPDATE ON THANHVIEN_HOIDONG
FOR EACH ROW
BEGIN
    DECLARE v_TrangThai VARCHAR(20);

    SELECT Trang_Thai
      INTO v_TrangThai
      FROM HOI_DONG
     WHERE Ma_HD = OLD.Ma_HD
     FOR UPDATE;

    IF v_TrangThai = 'DaChot' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không được cập nhật thành viên hội đồng sau DaChot.';
    END IF;

    IF NEW.Ma_HD <> OLD.Ma_HD OR NEW.Ma_GV <> OLD.Ma_GV THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không đổi khóa thành viên hội đồng; hãy DELETE rồi INSERT lại.';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_THANHVIEN_HOIDONG_bd$$
CREATE TRIGGER trg_THANHVIEN_HOIDONG_bd
BEFORE DELETE ON THANHVIEN_HOIDONG
FOR EACH ROW
BEGIN
    DECLARE v_TrangThai VARCHAR(20);

    SELECT Trang_Thai
      INTO v_TrangThai
      FROM HOI_DONG
     WHERE Ma_HD = OLD.Ma_HD
     FOR UPDATE;

    IF v_TrangThai = 'DaChot' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không được xóa thành viên hội đồng sau DaChot.';
    END IF;
END$$

-- ============================================================
-- HOI_DONG_DE_TAI
-- ============================================================
DROP TRIGGER IF EXISTS trg_HOI_DONG_DE_TAI_bi$$
CREATE TRIGGER trg_HOI_DONG_DE_TAI_bi
BEFORE INSERT ON HOI_DONG_DE_TAI
FOR EACH ROW
BEGIN
    DECLARE v_DotHD VARCHAR(20);
    DECLARE v_DotDT VARCHAR(20);

    SELECT Ma_Dot
      INTO v_DotHD
      FROM HOI_DONG
     WHERE Ma_HD = NEW.Ma_HD
     FOR UPDATE;

    SELECT Ma_Dot
      INTO v_DotDT
      FROM DE_TAI
     WHERE Ma_De_Tai = NEW.Ma_De_Tai
     FOR UPDATE;

    IF v_DotHD <> v_DotDT THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Hội đồng chỉ được chấm đề tài cùng đợt.';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM THANHVIEN_HOIDONG tv
          JOIN GVHD_DETAI g
            ON g.Ma_GV = tv.Ma_GV
           AND g.Ma_De_Tai = NEW.Ma_De_Tai
         WHERE tv.Ma_HD = NEW.Ma_HD
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Hội đồng có thành viên là GVHD của đề tài.';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_HOI_DONG_DE_TAI_bu$$
CREATE TRIGGER trg_HOI_DONG_DE_TAI_bu
BEFORE UPDATE ON HOI_DONG_DE_TAI
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Không cập nhật trực tiếp HOI_DONG_DE_TAI; hãy xóa/thêm lại khi chưa có điểm.';
END$$

DROP TRIGGER IF EXISTS trg_HOI_DONG_DE_TAI_bd$$
CREATE TRIGGER trg_HOI_DONG_DE_TAI_bd
BEFORE DELETE ON HOI_DONG_DE_TAI
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
          FROM DIEM_THANH_PHAN
         WHERE Ma_De_Tai = OLD.Ma_De_Tai
           AND Ma_Loai_Diem = 'HD'
    ) OR EXISTS (
        SELECT 1
          FROM KET_QUA_DE_TAI
         WHERE Ma_De_Tai = OLD.Ma_De_Tai
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không được gỡ đề tài khỏi hội đồng sau khi đã có điểm/kết quả.';
    END IF;
END$$

-- ============================================================
-- DIEM_THANH_PHAN
-- ============================================================
DROP TRIGGER IF EXISTS trg_DIEM_THANH_PHAN_bi$$
CREATE TRIGGER trg_DIEM_THANH_PHAN_bi
BEFORE INSERT ON DIEM_THANH_PHAN
FOR EACH ROW
BEGIN
    CALL sp_validate_diem(NEW.Ma_GV, NEW.Ma_De_Tai, NEW.Ma_Loai_Diem);

    -- Timestamp server, không tin giá trị client gửi.
    SET NEW.Ngay_Nop_Diem = CURRENT_TIMESTAMP;
END$$

DROP TRIGGER IF EXISTS trg_DIEM_THANH_PHAN_bu$$
CREATE TRIGGER trg_DIEM_THANH_PHAN_bu
BEFORE UPDATE ON DIEM_THANH_PHAN
FOR EACH ROW
BEGIN
    IF NEW.Ma_Diem <> OLD.Ma_Diem THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không được đổi Ma_Diem.';
    END IF;

    IF NOT (NEW.Ngay_Nop_Diem <=> OLD.Ngay_Nop_Diem) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ngay_Nop_Diem là timestamp hệ thống, không được sửa.';
    END IF;

    CALL sp_validate_diem(NEW.Ma_GV, NEW.Ma_De_Tai, NEW.Ma_Loai_Diem);
END$$

DROP TRIGGER IF EXISTS trg_DIEM_THANH_PHAN_bd$$
CREATE TRIGGER trg_DIEM_THANH_PHAN_bd
BEFORE DELETE ON DIEM_THANH_PHAN
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
          FROM KET_QUA_DE_TAI
         WHERE Ma_De_Tai = OLD.Ma_De_Tai
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Đề tài đã tổng hợp; không được xóa điểm thành phần.';
    END IF;
END$$

-- ============================================================
-- KET_QUA_DE_TAI:
-- - phải đủ GVPB + đủ điểm HD của tất cả thành viên
-- - Ma_GV_Tong_Hop = Chủ tịch đúng hội đồng
-- - tự tính Diem_Cuoi = AVG(AVG GVPB, AVG HD)
-- - INSERT kết quả là thời điểm khóa điểm.
-- ============================================================
DROP TRIGGER IF EXISTS trg_KET_QUA_DE_TAI_bi$$
CREATE TRIGGER trg_KET_QUA_DE_TAI_bi
BEFORE INSERT ON KET_QUA_DE_TAI
FOR EACH ROW
BEGIN
    DECLARE v_Ma_HD VARCHAR(20);
    DECLARE v_AvgGVPB DECIMAL(10,4);
    DECLARE v_AvgHD DECIMAL(10,4);
    DECLARE v_Missing INT DEFAULT 0;
    DECLARE v_Dummy VARCHAR(20);
    DECLARE v_TrangThaiDeTai VARCHAR(30);

    -- Lock đề tài, serialize với thao tác điểm.
    SELECT Ma_Dot, Trang_Thai
      INTO v_Dummy, v_TrangThaiDeTai
      FROM DE_TAI
     WHERE Ma_De_Tai = NEW.Ma_De_Tai
     FOR UPDATE;

    IF v_TrangThaiDeTai NOT IN ('DangThucHien','HoanThanh') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Chỉ tổng hợp kết quả khi đề tài đang thực hiện hoặc đã hoàn thành.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM NHOM
         WHERE Ma_De_Tai = NEW.Ma_De_Tai
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Đề tài chưa có nhóm thực hiện.';
    END IF;

    SELECT hd.Ma_HD
      INTO v_Ma_HD
      FROM HOI_DONG_DE_TAI hdt
      JOIN HOI_DONG hd ON hd.Ma_HD = hdt.Ma_HD
     WHERE hdt.Ma_De_Tai = NEW.Ma_De_Tai
       AND hd.Trang_Thai = 'DaChot'
     LIMIT 1;

    IF v_Ma_HD IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Đề tài chưa thuộc hội đồng đã chốt.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM THANHVIEN_HOIDONG
         WHERE Ma_HD = v_Ma_HD
           AND Ma_GV = NEW.Ma_GV_Tong_Hop
           AND Vai_Tro = 'ChuTich'
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Người tổng hợp phải là Chủ tịch đúng hội đồng.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM GVPB_DETAI g
          JOIN DIEM_THANH_PHAN d
            ON d.Ma_GV = g.Ma_GV
           AND d.Ma_De_Tai = g.Ma_De_Tai
           AND d.Ma_Loai_Diem = 'GVPB'
         WHERE g.Ma_De_Tai = NEW.Ma_De_Tai
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Chưa có đủ điểm GVPB.';
    END IF;

    SELECT COUNT(*)
      INTO v_Missing
      FROM THANHVIEN_HOIDONG tv
     WHERE tv.Ma_HD = v_Ma_HD
       AND NOT EXISTS (
            SELECT 1
              FROM DIEM_THANH_PHAN d
             WHERE d.Ma_De_Tai = NEW.Ma_De_Tai
               AND d.Ma_GV = tv.Ma_GV
               AND d.Ma_Loai_Diem = 'HD'
       );

    IF v_Missing > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Chưa đủ điểm hội đồng của tất cả thành viên.';
    END IF;

    SELECT AVG(Diem)
      INTO v_AvgGVPB
      FROM DIEM_THANH_PHAN
     WHERE Ma_De_Tai = NEW.Ma_De_Tai
       AND Ma_Loai_Diem = 'GVPB';

    SELECT AVG(Diem)
      INTO v_AvgHD
      FROM DIEM_THANH_PHAN
     WHERE Ma_De_Tai = NEW.Ma_De_Tai
       AND Ma_Loai_Diem = 'HD';

    IF v_AvgGVPB IS NULL OR v_AvgHD IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Thiếu loại điểm bắt buộc GVPB hoặc HD.';
    END IF;

    SET NEW.Diem_Cuoi = ROUND((v_AvgGVPB + v_AvgHD) / 2, 2);
    SET NEW.Trang_Thai_Cong_Bo = 'ChuaCongBo';
    SET NEW.Ngay_Tong_Hop = CURRENT_TIMESTAMP;
    SET NEW.Ngay_Cong_Bo = NULL;
END$$

DROP TRIGGER IF EXISTS trg_KET_QUA_DE_TAI_bu$$
CREATE TRIGGER trg_KET_QUA_DE_TAI_bu
BEFORE UPDATE ON KET_QUA_DE_TAI
FOR EACH ROW
BEGIN
    DECLARE v_Ma_HD VARCHAR(20);

    IF OLD.Trang_Thai_Cong_Bo = 'DaCongBo' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Kết quả đã công bố, không được sửa.';
    END IF;

    IF NEW.Ma_De_Tai <> OLD.Ma_De_Tai
       OR NEW.Diem_Cuoi <> OLD.Diem_Cuoi
       OR NEW.Ngay_Tong_Hop <> OLD.Ngay_Tong_Hop THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không được sửa khóa, Diem_Cuoi hoặc Ngay_Tong_Hop.';
    END IF;

    SELECT Ma_HD
      INTO v_Ma_HD
      FROM HOI_DONG_DE_TAI
     WHERE Ma_De_Tai = NEW.Ma_De_Tai
     LIMIT 1;

    IF NOT EXISTS (
        SELECT 1
          FROM THANHVIEN_HOIDONG
         WHERE Ma_HD = v_Ma_HD
           AND Ma_GV = NEW.Ma_GV_Tong_Hop
           AND Vai_Tro = 'ChuTich'
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Ma_GV_Tong_Hop phải là Chủ tịch đúng hội đồng.';
    END IF;

    IF NEW.Trang_Thai_Cong_Bo <> OLD.Trang_Thai_Cong_Bo THEN
        IF NOT (
            OLD.Trang_Thai_Cong_Bo = 'ChuaCongBo'
            AND NEW.Trang_Thai_Cong_Bo = 'DaCongBo'
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Chỉ được chuyển ChuaCongBo -> DaCongBo.';
        END IF;

        SET NEW.Ngay_Cong_Bo = CURRENT_TIMESTAMP;
    ELSE
        SET NEW.Ngay_Cong_Bo = OLD.Ngay_Cong_Bo;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_KET_QUA_DE_TAI_bd$$
CREATE TRIGGER trg_KET_QUA_DE_TAI_bd
BEFORE DELETE ON KET_QUA_DE_TAI
FOR EACH ROW
BEGIN
    IF OLD.Trang_Thai_Cong_Bo = 'DaCongBo' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Không được xóa kết quả đã công bố.';
    END IF;
END$$

-- ============================================================
-- BAO_CAO:
-- - chỉ trưởng nhóm của nhóm đã chọn đề tài được nộp
-- - server tự gán Ngay_Nop
-- - server tự tăng Lan_Nop
-- - bản ghi báo cáo là audit log: không UPDATE/DELETE.
-- ============================================================
DROP TRIGGER IF EXISTS trg_BAO_CAO_bi$$
CREATE TRIGGER trg_BAO_CAO_bi
BEFORE INSERT ON BAO_CAO
FOR EACH ROW
BEGIN
    DECLARE v_DeTai VARCHAR(20);
    DECLARE v_MaxLan INT DEFAULT 0;

    SELECT Ma_De_Tai
      INTO v_DeTai
      FROM NHOM
     WHERE Ma_Nhom = NEW.Ma_Nhom
     FOR UPDATE;

    IF v_DeTai IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Nhóm chưa chọn đề tài nên chưa được nộp báo cáo.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM THANH_VIEN_NHOM
         WHERE Ma_Nhom = NEW.Ma_Nhom
           AND Ma_SV = NEW.Ma_SV_Nguoi_Nop
           AND Vai_Tro = 'Truong_Nhom'
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Chỉ trưởng nhóm hiện tại được nộp báo cáo.';
    END IF;

    SELECT COALESCE(MAX(Lan_Nop),0)
      INTO v_MaxLan
      FROM BAO_CAO
     WHERE Ma_Nhom = NEW.Ma_Nhom;

    SET NEW.Lan_Nop = v_MaxLan + 1;
    SET NEW.Ngay_Nop = CURRENT_TIMESTAMP;
END$$

DROP TRIGGER IF EXISTS trg_BAO_CAO_bu$$
CREATE TRIGGER trg_BAO_CAO_bu
BEFORE UPDATE ON BAO_CAO
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Báo cáo là lịch sử nộp; muốn nộp bản mới hãy INSERT một dòng mới.';
END$$

DROP TRIGGER IF EXISTS trg_BAO_CAO_bd$$
CREATE TRIGGER trg_BAO_CAO_bd
BEFORE DELETE ON BAO_CAO
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Không xóa lịch sử nộp báo cáo.';
END$$

-- ============================================================
-- THONG_BAO:
-- NhaTruong: Admin
-- Khoa: Admin hoặc GV hiện có trong TRUONG_KHOA
-- ============================================================
DROP TRIGGER IF EXISTS trg_THONG_BAO_bi$$
CREATE TRIGGER trg_THONG_BAO_bi
BEFORE INSERT ON THONG_BAO
FOR EACH ROW
BEGIN
    DECLARE v_VaiTro VARCHAR(20);
    DECLARE v_MaGV VARCHAR(20);
    DECLARE v_TrangThai VARCHAR(20);

    SELECT Vai_Tro, Ma_GV, Trang_Thai
      INTO v_VaiTro, v_MaGV, v_TrangThai
      FROM TAI_KHOAN
     WHERE Ma_TK = NEW.Ma_TK;

    IF v_TrangThai <> 'HoatDong' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Tài khoản đang bị khóa.';
    END IF;

    IF NEW.Pham_Vi = 'NhaTruong' AND v_VaiTro <> 'Admin' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Chỉ Admin được đăng thông báo phạm vi NhaTruong.';
    END IF;

    IF NEW.Pham_Vi = 'Khoa'
       AND v_VaiTro <> 'Admin'
       AND NOT (
            v_VaiTro = 'GV'
            AND EXISTS (
                SELECT 1 FROM TRUONG_KHOA WHERE Ma_GV = v_MaGV
            )
       ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Thông báo Khoa chỉ do Admin hoặc Trưởng khoa đăng.';
    END IF;

    SET NEW.Ngay_Dang = CURRENT_TIMESTAMP;
END$$

DROP TRIGGER IF EXISTS trg_THONG_BAO_bu$$
CREATE TRIGGER trg_THONG_BAO_bu
BEFORE UPDATE ON THONG_BAO
FOR EACH ROW
BEGIN
    DECLARE v_VaiTro VARCHAR(20);
    DECLARE v_MaGV VARCHAR(20);
    DECLARE v_TrangThai VARCHAR(20);

    SELECT Vai_Tro, Ma_GV, Trang_Thai
      INTO v_VaiTro, v_MaGV, v_TrangThai
      FROM TAI_KHOAN
     WHERE Ma_TK = NEW.Ma_TK;

    IF v_TrangThai <> 'HoatDong' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Tài khoản đang bị khóa.';
    END IF;

    IF NEW.Pham_Vi = 'NhaTruong' AND v_VaiTro <> 'Admin' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Chỉ Admin được đăng thông báo phạm vi NhaTruong.';
    END IF;

    IF NEW.Pham_Vi = 'Khoa'
       AND v_VaiTro <> 'Admin'
       AND NOT (
            v_VaiTro = 'GV'
            AND EXISTS (
                SELECT 1 FROM TRUONG_KHOA WHERE Ma_GV = v_MaGV
            )
       ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Thông báo Khoa chỉ do Admin hoặc Trưởng khoa đăng.';
    END IF;
END$$

DELIMITER ;

-- ============================================================
-- END 02_logic_mysql.sql
-- ============================================================

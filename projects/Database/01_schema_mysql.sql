-- ============================================================
-- 01_schema_mysql.sql
-- HỆ THỐNG QUẢN LÝ ĐỀ TÀI SINH VIÊN
-- MySQL 8.0.16+
-- Đồng bộ với ERD hiện tại (19 bảng)
-- ============================================================

CREATE DATABASE IF NOT EXISTS quanlydetai
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE quanlydetai;

-- ============================================================
-- 1. BO_MON
-- ============================================================
CREATE TABLE IF NOT EXISTS BO_MON (
    Ma_Bo_Mon      VARCHAR(20)   NOT NULL,
    Ten_Bo_Mon     VARCHAR(150)  NOT NULL,

    CONSTRAINT PK_BO_MON PRIMARY KEY (Ma_Bo_Mon),
    CONSTRAINT UQ_BO_MON_Ten UNIQUE (Ten_Bo_Mon)
) ENGINE=InnoDB;

-- ============================================================
-- 2. GV
-- ============================================================
CREATE TABLE IF NOT EXISTS GV (
    Ma_GV          VARCHAR(20)   NOT NULL,
    Ho_Ten         VARCHAR(150)  NOT NULL,
    Email          VARCHAR(255)  NOT NULL,
    SDT            VARCHAR(20)   NULL,
    Ma_Bo_Mon      VARCHAR(20)   NOT NULL,

    CONSTRAINT PK_GV PRIMARY KEY (Ma_GV),
    CONSTRAINT UQ_GV_Email UNIQUE (Email),
    CONSTRAINT FK_GV_BO_MON
        FOREIGN KEY (Ma_Bo_Mon) REFERENCES BO_MON(Ma_Bo_Mon)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================
-- 3. SV
-- ============================================================
CREATE TABLE IF NOT EXISTS SV (
    Ma_SV          VARCHAR(20)   NOT NULL,
    Ho_Ten         VARCHAR(150)  NOT NULL,
    Email          VARCHAR(255)  NOT NULL,
    SDT            VARCHAR(20)   NULL,

    CONSTRAINT PK_SV PRIMARY KEY (Ma_SV),
    CONSTRAINT UQ_SV_Email UNIQUE (Email)
) ENGINE=InnoDB;

-- ============================================================
-- 4. TRUONG_KHOA
-- Phạm vi đồ án: quản lý chức vụ hiện tại, chưa lưu lịch sử nhiệm kỳ.
-- ============================================================
CREATE TABLE IF NOT EXISTS TRUONG_KHOA (
    Ma_GV          VARCHAR(20) NOT NULL,

    CONSTRAINT PK_TRUONG_KHOA PRIMARY KEY (Ma_GV),
    CONSTRAINT FK_TRUONG_KHOA_GV
        FOREIGN KEY (Ma_GV) REFERENCES GV(Ma_GV)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================
-- 5. DOT_DANG_KY
-- ============================================================
CREATE TABLE IF NOT EXISTS DOT_DANG_KY (
    Ma_Dot                    VARCHAR(20)   NOT NULL,
    Ma_Truong_Khoa            VARCHAR(20)   NOT NULL,
    Ten_Dot_Dang_Ky           VARCHAR(200)  NOT NULL,
    Loai                      VARCHAR(20)   NOT NULL,
    Begin_GV                  DATETIME      NOT NULL,
    End_GV                    DATETIME      NOT NULL,
    Begin_SV                  DATETIME      NOT NULL,
    End_SV                    DATETIME      NOT NULL,
    Deadline_GVPB_Nop_Diem    DATETIME      NULL,
    Time_BC_HD                DATETIME      NULL,

    CONSTRAINT PK_DOT_DANG_KY PRIMARY KEY (Ma_Dot),

    CONSTRAINT FK_DOT_TRUONG_KHOA
        FOREIGN KEY (Ma_Truong_Khoa) REFERENCES TRUONG_KHOA(Ma_GV)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT CK_DOT_Loai
        CHECK (Loai IN ('MonHoc','NCKH','TLCN','KLTN')),

    CONSTRAINT CK_DOT_GV_Time
        CHECK (Begin_GV < End_GV),

    CONSTRAINT CK_DOT_SV_Time
        CHECK (Begin_SV < End_SV),

    CONSTRAINT CK_DOT_2_GiaiDoan
        CHECK (End_GV <= Begin_SV),

    CONSTRAINT CK_DOT_Deadline_GVPB
        CHECK (
            (Loai IN ('MonHoc','NCKH') AND Deadline_GVPB_Nop_Diem IS NULL)
            OR
            (Loai IN ('TLCN','KLTN') AND Deadline_GVPB_Nop_Diem IS NOT NULL)
        ),

    CONSTRAINT CK_DOT_Time_BC_HD
        CHECK (
            (Loai = 'KLTN' AND Time_BC_HD IS NOT NULL)
            OR
            (Loai <> 'KLTN' AND Time_BC_HD IS NULL)
        )
) ENGINE=InnoDB;

-- ============================================================
-- 6. DE_TAI
-- ============================================================
CREATE TABLE IF NOT EXISTS DE_TAI (
    Ma_De_Tai       VARCHAR(20)   NOT NULL,
    Ten_De_Tai      VARCHAR(300)  NOT NULL,
    Ma_Bo_Mon       VARCHAR(20)   NOT NULL,
    Noi_Dung        TEXT          NOT NULL,
    Trang_Thai      VARCHAR(30)   NOT NULL DEFAULT 'Nhap',
    Ma_Dot          VARCHAR(20)   NOT NULL,
    Ma_GV_Dang_Ky   VARCHAR(20)   NOT NULL,
    Ngay_Dang_Ky    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT PK_DE_TAI PRIMARY KEY (Ma_De_Tai),

    -- Candidate key phục vụ composite FK từ NHOM.
    CONSTRAINT UQ_DE_TAI_MaDeTai_MaDot UNIQUE (Ma_De_Tai, Ma_Dot),

    CONSTRAINT FK_DE_TAI_BO_MON
        FOREIGN KEY (Ma_Bo_Mon) REFERENCES BO_MON(Ma_Bo_Mon)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT FK_DE_TAI_DOT
        FOREIGN KEY (Ma_Dot) REFERENCES DOT_DANG_KY(Ma_Dot)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT FK_DE_TAI_GV_DANG_KY
        FOREIGN KEY (Ma_GV_Dang_Ky) REFERENCES GV(Ma_GV)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT CK_DE_TAI_TrangThai
        CHECK (Trang_Thai IN ('Nhap','DaCongBo','DangThucHien','HoanThanh','Huy'))
) ENGINE=InnoDB;

-- ============================================================
-- 7. GVHD_DETAI
-- ============================================================
CREATE TABLE IF NOT EXISTS GVHD_DETAI (
    Ma_GV          VARCHAR(20) NOT NULL,
    Ma_De_Tai      VARCHAR(20) NOT NULL,

    CONSTRAINT PK_GVHD_DETAI PRIMARY KEY (Ma_GV, Ma_De_Tai),

    CONSTRAINT FK_GVHD_GV
        FOREIGN KEY (Ma_GV) REFERENCES GV(Ma_GV)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT FK_GVHD_DE_TAI
        FOREIGN KEY (Ma_De_Tai) REFERENCES DE_TAI(Ma_De_Tai)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================
-- 8. GVPB_DETAI
-- Mỗi đề tài tối đa 1 GVPB.
-- ============================================================
CREATE TABLE IF NOT EXISTS GVPB_DETAI (
    Ma_GV             VARCHAR(20) NOT NULL,
    Ma_De_Tai         VARCHAR(20) NOT NULL,
    Ngay_Phan_Cong    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT PK_GVPB_DETAI PRIMARY KEY (Ma_GV, Ma_De_Tai),
    CONSTRAINT UQ_GVPB_MaDeTai UNIQUE (Ma_De_Tai),

    CONSTRAINT FK_GVPB_GV
        FOREIGN KEY (Ma_GV) REFERENCES GV(Ma_GV)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT FK_GVPB_DE_TAI
        FOREIGN KEY (Ma_De_Tai) REFERENCES DE_TAI(Ma_De_Tai)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================
-- 9. NHOM
-- MySQL UNIQUE cho phép nhiều NULL nên dùng UNIQUE(Ma_De_Tai)
-- thay cho filtered unique index của SQL Server.
-- ============================================================
CREATE TABLE IF NOT EXISTS NHOM (
    Ma_Nhom             VARCHAR(20)   NOT NULL,
    Ten_Nhom            VARCHAR(150)  NOT NULL,
    Ma_Dot              VARCHAR(20)   NOT NULL,
    Ma_De_Tai           VARCHAR(20)   NULL,
    Ngay_Chon_De_Tai    DATETIME      NULL,

    CONSTRAINT PK_NHOM PRIMARY KEY (Ma_Nhom),
    CONSTRAINT UQ_NHOM_MaDeTai UNIQUE (Ma_De_Tai),

    CONSTRAINT FK_NHOM_DOT
        FOREIGN KEY (Ma_Dot) REFERENCES DOT_DANG_KY(Ma_Dot)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    -- Tự chặn nhóm đợt A chọn đề tài đợt B.
    CONSTRAINT FK_NHOM_DETAI_DOT
        FOREIGN KEY (Ma_De_Tai, Ma_Dot)
        REFERENCES DE_TAI(Ma_De_Tai, Ma_Dot)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT CK_NHOM_NgayChon
        CHECK (
            (Ma_De_Tai IS NULL AND Ngay_Chon_De_Tai IS NULL)
            OR
            (Ma_De_Tai IS NOT NULL AND Ngay_Chon_De_Tai IS NOT NULL)
        )
) ENGINE=InnoDB;

-- ============================================================
-- 10. THANH_VIEN_NHOM
-- ============================================================
CREATE TABLE IF NOT EXISTS THANH_VIEN_NHOM (
    Ma_Nhom        VARCHAR(20) NOT NULL,
    Ma_SV          VARCHAR(20) NOT NULL,
    Vai_Tro        VARCHAR(30) NOT NULL,

    CONSTRAINT PK_THANH_VIEN_NHOM PRIMARY KEY (Ma_Nhom, Ma_SV),

    CONSTRAINT FK_TVN_NHOM
        FOREIGN KEY (Ma_Nhom) REFERENCES NHOM(Ma_Nhom)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT FK_TVN_SV
        FOREIGN KEY (Ma_SV) REFERENCES SV(Ma_SV)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT CK_TVN_VaiTro
        CHECK (Vai_Tro IN ('Truong_Nhom','Thanh_Vien'))
) ENGINE=InnoDB;

-- ============================================================
-- 11. HOI_DONG
-- ============================================================
CREATE TABLE IF NOT EXISTS HOI_DONG (
    Ma_HD          VARCHAR(20) NOT NULL,
    Ma_Dot         VARCHAR(20) NOT NULL,
    Trang_Thai     VARCHAR(20) NOT NULL DEFAULT 'DangLap',

    CONSTRAINT PK_HOI_DONG PRIMARY KEY (Ma_HD),

    CONSTRAINT FK_HOI_DONG_DOT
        FOREIGN KEY (Ma_Dot) REFERENCES DOT_DANG_KY(Ma_Dot)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT CK_HOI_DONG_TrangThai
        CHECK (Trang_Thai IN ('DangLap','DaChot'))
) ENGINE=InnoDB;

-- ============================================================
-- 12. HOI_DONG_DE_TAI
-- 1 hội đồng có thể chấm nhiều đề tài; 1 đề tài tối đa 1 hội đồng.
-- ============================================================
CREATE TABLE IF NOT EXISTS HOI_DONG_DE_TAI (
    Ma_HD          VARCHAR(20) NOT NULL,
    Ma_De_Tai      VARCHAR(20) NOT NULL,

    CONSTRAINT PK_HOI_DONG_DE_TAI PRIMARY KEY (Ma_HD, Ma_De_Tai),
    CONSTRAINT UQ_HDDT_MaDeTai UNIQUE (Ma_De_Tai),

    CONSTRAINT FK_HDDT_HOI_DONG
        FOREIGN KEY (Ma_HD) REFERENCES HOI_DONG(Ma_HD)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT FK_HDDT_DE_TAI
        FOREIGN KEY (Ma_De_Tai) REFERENCES DE_TAI(Ma_De_Tai)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================
-- 13. THANHVIEN_HOIDONG
-- ============================================================
CREATE TABLE IF NOT EXISTS THANHVIEN_HOIDONG (
    Ma_HD          VARCHAR(20) NOT NULL,
    Ma_GV          VARCHAR(20) NOT NULL,
    Vai_Tro        VARCHAR(20) NOT NULL,

    CONSTRAINT PK_THANHVIEN_HOIDONG PRIMARY KEY (Ma_HD, Ma_GV),

    CONSTRAINT FK_TVHD_HOI_DONG
        FOREIGN KEY (Ma_HD) REFERENCES HOI_DONG(Ma_HD)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT FK_TVHD_GV
        FOREIGN KEY (Ma_GV) REFERENCES GV(Ma_GV)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT CK_TVHD_VaiTro
        CHECK (Vai_Tro IN ('ChuTich','ThuKy','ThanhVien'))
) ENGINE=InnoDB;

-- ============================================================
-- 14. LOAI_DIEM
-- Hai mã nghiệp vụ bắt buộc hiện tại: GVPB, HD.
-- ============================================================
CREATE TABLE IF NOT EXISTS LOAI_DIEM (
    Ma_Loai_Diem    VARCHAR(20)   NOT NULL,
    Ten_Loai_Diem   VARCHAR(150)  NOT NULL,

    CONSTRAINT PK_LOAI_DIEM PRIMARY KEY (Ma_Loai_Diem),
    CONSTRAINT UQ_LOAI_DIEM_Ten UNIQUE (Ten_Loai_Diem)
) ENGINE=InnoDB;

-- ============================================================
-- 15. DIEM_THANH_PHAN
-- ============================================================
CREATE TABLE IF NOT EXISTS DIEM_THANH_PHAN (
    Ma_Diem          VARCHAR(30)   NOT NULL,
    Ma_GV            VARCHAR(20)   NOT NULL,
    Ma_De_Tai        VARCHAR(20)   NOT NULL,
    Ma_Loai_Diem     VARCHAR(20)   NOT NULL,
    Diem             DECIMAL(5,2)  NOT NULL,
    Ngay_Cham        DATETIME      NOT NULL,
    Ngay_Nop_Diem    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Nhan_Xet         TEXT          NULL,

    CONSTRAINT PK_DIEM_THANH_PHAN PRIMARY KEY (Ma_Diem),

    CONSTRAINT UQ_DIEM_GV_DETAI_LOAI
        UNIQUE (Ma_GV, Ma_De_Tai, Ma_Loai_Diem),

    CONSTRAINT FK_DIEM_GV
        FOREIGN KEY (Ma_GV) REFERENCES GV(Ma_GV)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT FK_DIEM_DE_TAI
        FOREIGN KEY (Ma_De_Tai) REFERENCES DE_TAI(Ma_De_Tai)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT FK_DIEM_LOAI
        FOREIGN KEY (Ma_Loai_Diem) REFERENCES LOAI_DIEM(Ma_Loai_Diem)
        ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================
-- 16. KET_QUA_DE_TAI
-- Diem_Cuoi là snapshot chính thức, trigger tự tính.
-- Ket_Qua để VARCHAR vì PDF không quy định domain Dat/KhongDat cụ thể.
-- ============================================================
CREATE TABLE IF NOT EXISTS KET_QUA_DE_TAI (
    Ma_De_Tai               VARCHAR(20)   NOT NULL,
    Diem_Cuoi               DECIMAL(5,2)  NOT NULL,
    Nhan_Xet_Tong_Hop       TEXT          NULL,
    Ket_Qua                 VARCHAR(100)  NULL,
    Ma_GV_Tong_Hop          VARCHAR(20)   NOT NULL,
    Trang_Thai_Cong_Bo      VARCHAR(20)   NOT NULL DEFAULT 'ChuaCongBo',
    Ngay_Tong_Hop           DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Ngay_Cong_Bo            DATETIME      NULL,

    CONSTRAINT PK_KET_QUA_DE_TAI PRIMARY KEY (Ma_De_Tai),

    CONSTRAINT FK_KQ_DE_TAI
        FOREIGN KEY (Ma_De_Tai) REFERENCES DE_TAI(Ma_De_Tai)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT FK_KQ_GV_TONG_HOP
        FOREIGN KEY (Ma_GV_Tong_Hop) REFERENCES GV(Ma_GV)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT CK_KQ_TrangThaiCB
        CHECK (Trang_Thai_Cong_Bo IN ('ChuaCongBo','DaCongBo')),

    CONSTRAINT CK_KQ_TrangThai_Ngay
        CHECK (
            (Trang_Thai_Cong_Bo = 'ChuaCongBo' AND Ngay_Cong_Bo IS NULL)
            OR
            (Trang_Thai_Cong_Bo = 'DaCongBo' AND Ngay_Cong_Bo IS NOT NULL)
        ),

    CONSTRAINT CK_KQ_NgayCongBo
        CHECK (Ngay_Cong_Bo IS NULL OR Ngay_Cong_Bo >= Ngay_Tong_Hop)
) ENGINE=InnoDB;

-- ============================================================
-- 17. TAI_KHOAN
-- MySQL UNIQUE cho phép nhiều NULL -> không cần filtered index.
-- ============================================================
CREATE TABLE IF NOT EXISTS TAI_KHOAN (
    Ma_TK                       VARCHAR(30)   NOT NULL,
    Ma_SV                       VARCHAR(20)   NULL,
    Ma_GV                       VARCHAR(20)   NULL,
    Ten_Dang_Nhap               VARCHAR(100)  NOT NULL,
    Mat_Khau_Hash               VARCHAR(255)  NOT NULL,
    Vai_Tro                     VARCHAR(20)   NOT NULL,
    Trang_Thai                  VARCHAR(20)   NOT NULL DEFAULT 'HoatDong',
    Ngay_Tao                    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Lan_Dang_Nhap_CuoiCung      DATETIME      NULL,

    CONSTRAINT PK_TAI_KHOAN PRIMARY KEY (Ma_TK),

    CONSTRAINT UQ_TK_TenDangNhap UNIQUE (Ten_Dang_Nhap),
    CONSTRAINT UQ_TK_MaSV UNIQUE (Ma_SV),
    CONSTRAINT UQ_TK_MaGV UNIQUE (Ma_GV),

    CONSTRAINT FK_TK_SV
        FOREIGN KEY (Ma_SV) REFERENCES SV(Ma_SV)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT FK_TK_GV
        FOREIGN KEY (Ma_GV) REFERENCES GV(Ma_GV)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT CK_TK_VaiTro
        CHECK (Vai_Tro IN ('SV','GV','Admin')),

    CONSTRAINT CK_TK_TrangThai
        CHECK (Trang_Thai IN ('HoatDong','Khoa')),

    CONSTRAINT CK_TK_XOR
        CHECK (
            (Vai_Tro = 'SV' AND Ma_SV IS NOT NULL AND Ma_GV IS NULL)
            OR
            (Vai_Tro = 'GV' AND Ma_GV IS NOT NULL AND Ma_SV IS NULL)
            OR
            (Vai_Tro = 'Admin' AND Ma_SV IS NULL AND Ma_GV IS NULL)
        )
) ENGINE=InnoDB;

-- ============================================================
-- 18. THONG_BAO
-- ============================================================
CREATE TABLE IF NOT EXISTS THONG_BAO (
    Ma_TB          VARCHAR(30)   NOT NULL,
    Tieu_De        VARCHAR(300)  NOT NULL,
    Noi_Dung       TEXT          NOT NULL,
    Ngay_Dang      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Pham_Vi        VARCHAR(20)   NOT NULL,
    Ma_TK          VARCHAR(30)   NOT NULL,

    CONSTRAINT PK_THONG_BAO PRIMARY KEY (Ma_TB),

    CONSTRAINT FK_TB_TAI_KHOAN
        FOREIGN KEY (Ma_TK) REFERENCES TAI_KHOAN(Ma_TK)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT CK_TB_PhamVi
        CHECK (Pham_Vi IN ('NhaTruong','Khoa'))
) ENGINE=InnoDB;

-- ============================================================
-- 19. BAO_CAO
-- Bản mới nhất = MAX(Lan_Nop)
-- ============================================================
CREATE TABLE IF NOT EXISTS BAO_CAO (
    Ma_BC                VARCHAR(30)   NOT NULL,
    Ma_Nhom              VARCHAR(20)   NOT NULL,
    Ma_SV_Nguoi_Nop      VARCHAR(20)   NOT NULL,
    Ngay_Nop             DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    File_Dinh_Kem        VARCHAR(500)  NOT NULL,
    Lan_Nop              INT           NOT NULL,

    CONSTRAINT PK_BAO_CAO PRIMARY KEY (Ma_BC),
    CONSTRAINT UQ_BC_Nhom_Lan UNIQUE (Ma_Nhom, Lan_Nop),

    CONSTRAINT FK_BC_NHOM
        FOREIGN KEY (Ma_Nhom) REFERENCES NHOM(Ma_Nhom)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT FK_BC_SV
        FOREIGN KEY (Ma_SV_Nguoi_Nop) REFERENCES SV(Ma_SV)
        ON UPDATE RESTRICT ON DELETE RESTRICT,

    CONSTRAINT CK_BC_LanNop
        CHECK (Lan_Nop > 0)
) ENGINE=InnoDB;

-- ============================================================
-- END 01_schema_mysql.sql
-- ============================================================

QUAN LY DE TAI - HUONG DAN CHAY MYSQL
=========================================

YEU CAU
-------
- MySQL Server 8.0.16 tro len.
- Khuyen nghi MySQL 8.0.x moi.
- Khong dung ZIP SQL Server cu tren MySQL vi cu phap khac nhau.

THU TU CHAY
-----------
1) 01_schema_mysql.sql
2) 02_logic_mysql.sql
3) 03_views_seed_mysql.sql

MYSQL WORKBENCH
---------------
1. Mo MySQL Workbench va ket noi MySQL Server..( Database( góc trên bên trái)->Conection DataBase)
2. File > Open SQL Script...
3. Mo 01_schema_mysql.sql.
4. Bam bieu tuong tia set (Execute All).
5. Lam tuong tu voi 02_logic_mysql.sql.
6. Lam tuong tu voi 03_views_seed_mysql.sql.
7. Refresh SCHEMAS, ban se thay database: quanlydetai.

KIEM TRA
--------
USE quanlydetai;

SHOW TABLES;
SHOW TRIGGERS;
SHOW PROCEDURE STATUS WHERE Db = 'quanlydetai';

SELECT * FROM LOAI_DIEM;
SELECT * FROM VW_DE_TAI_DA_CONG_BO;
SELECT * FROM VW_KET_QUA_DA_CONG_BO;

So bang nghiep vu: 19
Views: 4
Stored procedure helper: sp_validate_diem
Triggers: bao ve state machine, GVHD/GVPB, nhom, hoi dong, diem, ket qua,
          bao cao va thong bao.

CHAY BANG COMMAND LINE
----------------------
Windows PowerShell / CMD:

mysql -u root -p < 01_schema_mysql.sql
mysql -u root -p quanlydetai < 02_logic_mysql.sql
mysql -u root -p quanlydetai < 03_views_seed_mysql.sql

Neu lenh mysql khong duoc nhan dien, mo MySQL Command Line Client
hoac them thu muc bin cua MySQL vao PATH.

LUU Y QUAN TRONG
----------------
- Cac script nay danh cho MySQL, KHONG phai MariaDB.
- CHECK constraint can MySQL 8.0.16+ de duoc enforce dung.
- Mat_Khau_Hash chi luu hash. Backend phai hash bang Argon2id/bcrypt.
- Ket_Qua hien de VARCHAR tu do vi tai lieu nghiep vu khong quy dinh
  tap gia tri Dat/KhongDat cu the.
- Diem_Cuoi la snapshot: trigger tu tinh khi INSERT KET_QUA_DE_TAI.
  Sau khi co ket qua, DIEM_THANH_PHAN bi khoa.
- NHOM.Ma_De_Tai la UNIQUE va nullable. MySQL cho phep nhieu NULL,
  nen khong can filtered unique index nhu SQL Server.
- BAO_CAO.Lan_Nop va Ngay_Nop duoc trigger tu gan; muon nop lai thi INSERT ban moi.

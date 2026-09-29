package com.example.quanlydetai.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import org.hibernate.annotations.Formula;

@Entity
@Table(name = "TRUONG_KHOA")
public class TruongKhoa {

    @Id
    @jakarta.persistence.Column(name = "Ma_GV")
    private String maGV;

    // Lấy Họ tên trực tiếp từ bảng GV để hiển thị, không cần quan hệ phức tạp.
    @Formula("(SELECT g.Ho_Ten FROM GV g WHERE g.Ma_GV = {alias}.Ma_GV)")
    private String hoTen;

    public String getMaGV() { return maGV; }
    public String getHoTen() { return hoTen; }
}
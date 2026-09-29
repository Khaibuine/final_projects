package com.example.quanlydetai.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "DOT_DANG_KY")
public class DotDangKy {

    @Id
    @Column(name = "Ma_Dot")
    private String maDot;

    @Column(name = "Ma_Truong_Khoa")
    private String maTruongKhoa;

    @Column(name = "Ten_Dot_Dang_Ky")
    private String tenDotDangKy;

    @Column(name = "Loai")
    private String loai;

    @Column(name = "Begin_GV")
    private LocalDateTime beginGV;

    @Column(name = "End_GV")
    private LocalDateTime endGV;

    @Column(name = "Begin_SV")
    private LocalDateTime beginSV;

    @Column(name = "End_SV")
    private LocalDateTime endSV;

    @Column(name = "Deadline_GVPB_Nop_Diem")
    private LocalDateTime deadlineGvpbNopDiem;

    @Column(name = "Time_BC_HD")
    private LocalDateTime timeBcHd;

    public String getMaDot() { return maDot; }
    public void setMaDot(String maDot) { this.maDot = maDot; }
    public String getMaTruongKhoa() { return maTruongKhoa; }
    public void setMaTruongKhoa(String maTruongKhoa) { this.maTruongKhoa = maTruongKhoa; }
    public String getTenDotDangKy() { return tenDotDangKy; }
    public void setTenDotDangKy(String tenDotDangKy) { this.tenDotDangKy = tenDotDangKy; }
    public String getLoai() { return loai; }
    public void setLoai(String loai) { this.loai = loai; }
    public LocalDateTime getBeginGV() { return beginGV; }
    public void setBeginGV(LocalDateTime beginGV) { this.beginGV = beginGV; }
    public LocalDateTime getEndGV() { return endGV; }
    public void setEndGV(LocalDateTime endGV) { this.endGV = endGV; }
    public LocalDateTime getBeginSV() { return beginSV; }
    public void setBeginSV(LocalDateTime beginSV) { this.beginSV = beginSV; }
    public LocalDateTime getEndSV() { return endSV; }
    public void setEndSV(LocalDateTime endSV) { this.endSV = endSV; }
    public LocalDateTime getDeadlineGvpbNopDiem() { return deadlineGvpbNopDiem; }
    public void setDeadlineGvpbNopDiem(LocalDateTime deadlineGvpbNopDiem) { this.deadlineGvpbNopDiem = deadlineGvpbNopDiem; }
    public LocalDateTime getTimeBcHd() { return timeBcHd; }
    public void setTimeBcHd(LocalDateTime timeBcHd) { this.timeBcHd = timeBcHd; }
}
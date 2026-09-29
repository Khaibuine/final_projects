package com.example.quanlydetai.dto;

import org.springframework.format.annotation.DateTimeFormat;
import java.time.LocalDateTime;

public class DotDangKyForm {

    private String maDot;
    private String maTruongKhoa;
    private String tenDotDangKy;
    private String loai;

    @DateTimeFormat(pattern = "yyyy-MM-dd'T'HH:mm")
    private LocalDateTime beginGV;

    @DateTimeFormat(pattern = "yyyy-MM-dd'T'HH:mm")
    private LocalDateTime endGV;

    @DateTimeFormat(pattern = "yyyy-MM-dd'T'HH:mm")
    private LocalDateTime beginSV;

    @DateTimeFormat(pattern = "yyyy-MM-dd'T'HH:mm")
    private LocalDateTime endSV;

    @DateTimeFormat(pattern = "yyyy-MM-dd'T'HH:mm")
    private LocalDateTime deadlineGvpbNopDiem;

    @DateTimeFormat(pattern = "yyyy-MM-dd'T'HH:mm")
    private LocalDateTime timeBcHd;

    // getters & setters
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
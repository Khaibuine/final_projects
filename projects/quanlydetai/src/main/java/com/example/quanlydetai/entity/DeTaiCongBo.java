package com.example.quanlydetai.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.Immutable;
import java.time.LocalDateTime;

// Ánh xạ tới VIEW (chỉ đọc), không phải bảng gốc DE_TAI.
@Entity
@Immutable
@Table(name = "VW_DE_TAI_DA_CONG_BO")
public class DeTaiCongBo {

    @Id
    @Column(name = "Ma_De_Tai")
    private String maDeTai;

    @Column(name = "Ten_De_Tai")
    private String tenDeTai;

    @Column(name = "Noi_Dung")
    private String noiDung;

    @Column(name = "Ma_Dot")
    private String maDot;

    @Column(name = "Ngay_Dang_Ky")
    private LocalDateTime ngayDangKy;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "Ma_Bo_Mon", referencedColumnName = "maBoMon", insertable = false, updatable = false)
    private BoMon boMon;

    public String getMaDeTai() { return maDeTai; }
    public String getTenDeTai() { return tenDeTai; }
    public String getNoiDung() { return noiDung; }
    public String getMaDot() { return maDot; }
    public LocalDateTime getNgayDangKy() { return ngayDangKy; }
    public BoMon getBoMon() { return boMon; }
}
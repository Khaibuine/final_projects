package com.example.quanlydetai.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "BO_MON")
public class BoMon {

    @Id
    private String maBoMon;

    private String tenBoMon;

    public String getMaBoMon() { return maBoMon; }
    public void setMaBoMon(String maBoMon) { this.maBoMon = maBoMon; }
    public String getTenBoMon() { return tenBoMon; }
    public void setTenBoMon(String tenBoMon) { this.tenBoMon = tenBoMon; }
}
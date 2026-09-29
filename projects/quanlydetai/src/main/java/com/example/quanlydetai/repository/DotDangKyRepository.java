package com.example.quanlydetai.repository;

import com.example.quanlydetai.entity.DotDangKy;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface DotDangKyRepository extends JpaRepository<DotDangKy, String> {
    List<DotDangKy> findAllByOrderByBeginGVDesc();
}
package com.example.quanlydetai.controller;

import com.example.quanlydetai.repository.DeTaiCongBoRepository;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class DeTaiController {

    private final DeTaiCongBoRepository deTaiCongBoRepository;

    public DeTaiController(DeTaiCongBoRepository deTaiCongBoRepository) {
        this.deTaiCongBoRepository = deTaiCongBoRepository;
    }

    @GetMapping("/de-tai")
    public String danhSach(Model model) {
        model.addAttribute("dsDeTai", deTaiCongBoRepository.findAll());
        return "sv/de-tai-list";
    }
}
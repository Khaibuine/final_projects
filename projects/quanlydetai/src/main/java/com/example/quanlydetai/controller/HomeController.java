package com.example.quanlydetai.controller;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class HomeController {

    @GetMapping("/")
    public String home(Model model) {
        model.addAttribute("tieuDe", "Hệ thống quản lý đề tài sinh viên");
        return "home";
    }

    @GetMapping("/login")
    public String login() {
        return "auth/login";
    }
}
package com.example.quanlydetai.controller;

import com.example.quanlydetai.dto.DotDangKyForm;
import com.example.quanlydetai.entity.DotDangKy;
import com.example.quanlydetai.repository.DotDangKyRepository;
import com.example.quanlydetai.repository.TruongKhoaRepository;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import java.util.ArrayList;
import java.util.List;

@Controller
@RequestMapping("/truong-khoa/dot")
public class DotDangKyController {

    private final DotDangKyRepository dotDangKyRepository;
    private final TruongKhoaRepository truongKhoaRepository;

    public DotDangKyController(DotDangKyRepository dotDangKyRepository,
                                TruongKhoaRepository truongKhoaRepository) {
        this.dotDangKyRepository = dotDangKyRepository;
        this.truongKhoaRepository = truongKhoaRepository;
    }

    @GetMapping
    public String danhSach(Model model) {
        model.addAttribute("dsDot", dotDangKyRepository.findAllByOrderByBeginGVDesc());
        model.addAttribute("dsTruongKhoa", truongKhoaRepository.findAll());
        if (!model.containsAttribute("form")) {
            model.addAttribute("form", new DotDangKyForm());
        }
        return "truongkhoa/dot-list";
    }

    @PostMapping
    public String taoDot(@ModelAttribute("form") DotDangKyForm form, RedirectAttributes redirect) {
    List<String> loi = kiemTra(form);
    if (!isBlank(form.getMaDot()) && dotDangKyRepository.existsById(form.getMaDot())) {
        loi.add("Mã đợt \"" + form.getMaDot() + "\" đã tồn tại, vui lòng chọn mã khác.");
    }
    if (!loi.isEmpty()) {
        redirect.addFlashAttribute("loi", loi);
        redirect.addFlashAttribute("form", form);
        return "redirect:/truong-khoa/dot";
    }

        DotDangKy dot = new DotDangKy();
        dot.setMaDot(form.getMaDot());
        dot.setMaTruongKhoa(form.getMaTruongKhoa());
        dot.setTenDotDangKy(form.getTenDotDangKy());
        dot.setLoai(form.getLoai());
        dot.setBeginGV(form.getBeginGV());
        dot.setEndGV(form.getEndGV());
        dot.setBeginSV(form.getBeginSV());
        dot.setEndSV(form.getEndSV());
        dot.setDeadlineGvpbNopDiem(form.getDeadlineGvpbNopDiem());
        dot.setTimeBcHd(form.getTimeBcHd());

        try {
            dotDangKyRepository.save(dot);
            redirect.addFlashAttribute("thanhCong", "Đã tạo đợt đăng ký \"" + form.getTenDotDangKy() + "\".");
        } catch (DataIntegrityViolationException ex) {
            redirect.addFlashAttribute("loi", List.of("Không lưu được: " + rootMessage(ex)));
            redirect.addFlashAttribute("form", form);
        }
        return "redirect:/truong-khoa/dot";
    }

    private List<String> kiemTra(DotDangKyForm f) {
        List<String> loi = new ArrayList<>();
        if (isBlank(f.getMaDot())) loi.add("Mã đợt không được để trống.");
        if (isBlank(f.getMaTruongKhoa())) loi.add("Phải chọn Trưởng khoa tạo đợt.");
        if (isBlank(f.getTenDotDangKy())) loi.add("Tên đợt không được để trống.");
        if (isBlank(f.getLoai())) loi.add("Phải chọn loại đợt.");

        if (f.getBeginGV() != null && f.getEndGV() != null && !f.getBeginGV().isBefore(f.getEndGV())) {
            loi.add("Thời gian bắt đầu GV đăng ký phải trước thời gian kết thúc.");
        }
        if (f.getBeginSV() != null && f.getEndSV() != null && !f.getBeginSV().isBefore(f.getEndSV())) {
            loi.add("Thời gian bắt đầu SV đăng ký phải trước thời gian kết thúc.");
        }
        if (f.getEndGV() != null && f.getBeginSV() != null && f.getEndGV().isAfter(f.getBeginSV())) {
            loi.add("Giai đoạn SV đăng ký phải bắt đầu sau khi giai đoạn GV đăng ký kết thúc.");
        }

        if (f.getLoai() != null) {
            boolean canDeadlineGvpb = f.getLoai().equals("TLCN") || f.getLoai().equals("KLTN");
            if (canDeadlineGvpb && f.getDeadlineGvpbNopDiem() == null) {
                loi.add("Đợt loại TLCN/KLTN bắt buộc phải có hạn chót GVPB nộp điểm.");
            }
            if (!canDeadlineGvpb && f.getDeadlineGvpbNopDiem() != null) {
                loi.add("Đợt MonHoc/NCKH không được đặt hạn chót GVPB nộp điểm.");
            }
            boolean isKLTN = f.getLoai().equals("KLTN");
            if (isKLTN && f.getTimeBcHd() == null) {
                loi.add("Đợt loại KLTN bắt buộc phải có ngày báo cáo hội đồng.");
            }
            if (!isKLTN && f.getTimeBcHd() != null) {
                loi.add("Chỉ đợt loại KLTN mới được đặt ngày báo cáo hội đồng.");
            }
        }
        return loi;
    }

    private boolean isBlank(String s) { return s == null || s.isBlank(); }

    private String rootMessage(Throwable ex) {
        Throwable cur = ex;
        while (cur.getCause() != null) cur = cur.getCause();
        return cur.getMessage();
    }
}
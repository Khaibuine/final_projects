package com.example.quanlydetai.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.factory.PasswordEncoderFactories;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class SecurityConfig {

    @Bean
    SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/login", "/css/**", "/js/**").permitAll()
                .requestMatchers("/truong-khoa/**").hasRole("TRUONGKHOA")
                .requestMatchers("/gv/**").hasAnyRole("GV", "TRUONGKHOA")
                .requestMatchers("/sv/**").hasRole("SV")
                .requestMatchers("/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated())
            .formLogin(form -> form
                .loginPage("/login")
                .defaultSuccessUrl("/", true)
                .permitAll())
            .logout(logout -> logout.logoutSuccessUrl("/login?logout"));
        return http.build();
    }

    @Bean
    PasswordEncoder passwordEncoder() {
        return PasswordEncoderFactories.createDelegatingPasswordEncoder();
    }

    // TẠM THỜI: tài khoản trong bộ nhớ để dựng giao diện.
    // Sẽ thay bằng UserDetailsService đọc từ bảng TAI_KHOAN khi làm phần đăng nhập thật.
    @Bean
    UserDetailsService userDetailsService(PasswordEncoder encoder) {
        UserDetails sv = User.withUsername("sv01")
            .password(encoder.encode("123456")).roles("SV").build();
        UserDetails gv = User.withUsername("gv01")
            .password(encoder.encode("123456")).roles("GV").build();
        UserDetails truongKhoa = User.withUsername("truongkhoa")
            .password(encoder.encode("123456")).roles("GV", "TRUONGKHOA").build();
        UserDetails admin = User.withUsername("admin")
            .password(encoder.encode("123456")).roles("ADMIN").build();
        return new InMemoryUserDetailsManager(sv, gv, truongKhoa, admin);
    }
}
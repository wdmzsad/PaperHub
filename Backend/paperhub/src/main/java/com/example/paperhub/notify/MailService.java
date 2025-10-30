package com.example.paperhub.notify;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;
import jakarta.mail.internet.MimeMessage;

@Service
public class MailService {
    @Autowired
    private JavaMailSender mailSender;

    public void sendVerificationMail(String to, String code) {
        send("【PaperHub注册验证码】", String.format("您的邮箱验证码为：%s，5分钟内有效。", code), to);
    }

    public void sendResetMail(String to, String code) {
        send("【PaperHub重置密码】", String.format("您的重置验证码为：%s，10分钟内有效。", code), to);
    }

    private void send(String subject, String text, String to) {
        try {
            MimeMessage msg = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(msg, true, "UTF-8");
            helper.setTo(to);
            helper.setSubject(subject);
            helper.setText(text, false);
            helper.setFrom("paperhub2025@163.com");
            mailSender.send(msg);
        } catch (Exception e) {
            System.err.println("发邮件失败: " + e.getMessage());
        }
    }
}



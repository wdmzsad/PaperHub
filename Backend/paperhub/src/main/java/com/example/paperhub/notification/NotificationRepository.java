package com.example.paperhub.notification;

import com.example.paperhub.auth.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface NotificationRepository extends JpaRepository<Notification, Long> {
    // 根据接收者查找通知
    Page<Notification> findByRecipientOrderByCreatedAtDesc(User recipient, Pageable pageable);

    // 根据接收者和类型查找通知
    Page<Notification> findByRecipientAndTypeOrderByCreatedAtDesc(User recipient, NotificationType type, Pageable pageable);

    // 根据接收者和类型列表查找通知
    @Query("SELECT n FROM Notification n WHERE n.recipient = :recipient AND n.type IN :types ORDER BY n.createdAt DESC")
    Page<Notification> findByRecipientAndTypeInOrderByCreatedAtDesc(
            @Param("recipient") User recipient,
            @Param("types") List<NotificationType> types,
            Pageable pageable);

    // 统计未读通知数量
    long countByRecipientAndReadFalse(User recipient);

    // 查找未读通知
    List<Notification> findByRecipientAndReadFalse(User recipient);

    // 查找特定类型的未读通知
    List<Notification> findByRecipientAndTypeAndReadFalse(User recipient, NotificationType type);

    // 查找特定类型的未读通知数量
    long countByRecipientAndTypeAndReadFalse(User recipient, NotificationType type);
}


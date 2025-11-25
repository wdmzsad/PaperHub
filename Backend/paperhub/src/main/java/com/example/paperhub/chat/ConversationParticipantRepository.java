package com.example.paperhub.chat;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface ConversationParticipantRepository extends JpaRepository<ConversationParticipant, Long> {

    List<ConversationParticipant> findByConversationId(Long conversationId);

    Optional<ConversationParticipant> findByConversationIdAndUserId(Long conversationId, Long userId);

    @Modifying
    @Query("UPDATE ConversationParticipant cp SET cp.lastReadAt = :lastReadAt " +
           "WHERE cp.conversation.id = :conversationId AND cp.userId = :userId")
    void updateLastReadAt(@Param("conversationId") Long conversationId,
                         @Param("userId") Long userId,
                         @Param("lastReadAt") LocalDateTime lastReadAt);

    boolean existsByConversationIdAndUserId(Long conversationId, Long userId);
}
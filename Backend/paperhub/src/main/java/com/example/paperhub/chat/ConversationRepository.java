package com.example.paperhub.chat;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ConversationRepository extends JpaRepository<Conversation, Long> {

    @Query("SELECT c FROM Conversation c JOIN ConversationParticipant cp ON c.id = cp.conversation.id " +
           "WHERE cp.userId = :userId ORDER BY c.updatedAt DESC")
    List<Conversation> findByUserId(@Param("userId") Long userId);

    @Query("SELECT c FROM Conversation c JOIN ConversationParticipant cp1 ON c.id = cp1.conversation.id " +
           "JOIN ConversationParticipant cp2 ON c.id = cp2.conversation.id " +
           "WHERE cp1.userId = :userId1 AND cp2.userId = :userId2 AND c.type = 'PRIVATE'")
    Optional<Conversation> findPrivateConversationBetweenUsers(
            @Param("userId1") Long userId1,
            @Param("userId2") Long userId2);

    @Query("SELECT COUNT(m) FROM Message m JOIN ConversationParticipant cp ON m.conversation.id = cp.conversation.id " +
           "WHERE m.conversation.id = :conversationId AND m.senderId != :userId AND cp.userId = :userId " +
           "AND (m.createdAt > cp.lastReadAt OR cp.lastReadAt IS NULL)")
    Long countUnreadMessages(@Param("conversationId") Long conversationId, @Param("userId") Long userId);
}
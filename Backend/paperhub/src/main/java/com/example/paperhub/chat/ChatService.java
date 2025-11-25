package com.example.paperhub.chat;

import com.example.paperhub.chat.dto.ConversationResponse;
import com.example.paperhub.chat.dto.MessageResponse;
import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.websocket.ChatWebSocketService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Service
@Transactional
public class ChatService {

    @Autowired
    private ConversationRepository conversationRepository;

    @Autowired
    private ConversationParticipantRepository conversationParticipantRepository;

    @Autowired
    private MessageRepository messageRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ChatWebSocketService chatWebSocketService;

    /**
     * 获取用户的所有会话列表
     */
    public List<ConversationResponse> getUserConversations(Long userId) {
        List<Conversation> conversations = conversationRepository.findByUserId(userId);
        List<ConversationResponse> responses = new ArrayList<>();

        for (Conversation conversation : conversations) {
            // 获取会话的另一方用户信息
            Long otherUserId = getOtherParticipantId(conversation, userId);
            Optional<User> otherUser = userRepository.findById(otherUserId);

            if (otherUser.isPresent()) {
                User user = otherUser.get();

                // 获取最后一条消息
                Message lastMessage = getLastMessage(conversation.getId());

                // 获取未读消息数
                Integer unreadCount = getUnreadCount(conversation.getId(), userId);

                responses.add(new ConversationResponse(
                    conversation,
                    lastMessage,
                    unreadCount,
                    user.getName(),
                    user.getAvatar(),
                    false // TODO: 实现在线状态
                ));
            }
        }

        return responses;
    }

    /**
     * 创建或获取私聊会话
     */
    public Conversation createOrGetPrivateConversation(Long currentUserId, Long targetUserId) {
        // 检查是否已存在私聊会话
        Optional<Conversation> existingConversation = conversationRepository
                .findPrivateConversationBetweenUsers(currentUserId, targetUserId);

        if (existingConversation.isPresent()) {
            return existingConversation.get();
        }

        // 创建新的私聊会话
        Conversation conversation = new Conversation();
        conversation.setType(ConversationType.PRIVATE);
        conversation.setCreatedAt(LocalDateTime.now());
        conversation.setUpdatedAt(LocalDateTime.now());
        conversation = conversationRepository.save(conversation);

        // 添加参与者
        addParticipant(conversation, currentUserId);
        addParticipant(conversation, targetUserId);

        return conversation;
    }

    /**
     * 获取会话消息
     */
    public Page<MessageResponse> getConversationMessages(Long conversationId, Long userId, int page, int size) {
        // 验证用户是否在会话中
        if (!conversationParticipantRepository.existsByConversationIdAndUserId(conversationId, userId)) {
            throw new RuntimeException("用户不在该会话中");
        }

        // 标记为已读
        markAsRead(conversationId, userId);

        Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<Message> messages = messageRepository.findByConversationIdOrderByCreatedAtDesc(conversationId, pageable);

        return messages.map(message -> {
            MessageResponse response = new MessageResponse(message);

            // 设置发送者信息
            Optional<User> sender = userRepository.findById(message.getSenderId());
            if (sender.isPresent()) {
                User user = sender.get();
                response.setSenderName(user.getName());
                response.setSenderAvatar(user.getAvatar());
            }

            // 设置是否是自己发送的消息
            response.setIsMe(message.getSenderId().equals(userId));

            return response;
        });
    }

    /**
     * 发送消息
     */
    public Message sendMessage(Long conversationId, Long senderId, String content, MessageType type,
                              String fileUrl, String fileName, Long fileSize) {
        // 验证用户是否在会话中
        if (!conversationParticipantRepository.existsByConversationIdAndUserId(conversationId, senderId)) {
            throw new RuntimeException("用户不在该会话中");
        }

        Optional<Conversation> conversationOpt = conversationRepository.findById(conversationId);
        if (conversationOpt.isEmpty()) {
            throw new RuntimeException("会话不存在");
        }

        Message message = new Message();
        message.setConversation(conversationOpt.get());
        message.setSenderId(senderId);
        message.setContent(content);
        message.setType(type);
        message.setFileUrl(fileUrl);
        message.setFileName(fileName);
        message.setFileSize(fileSize);
        message.setCreatedAt(LocalDateTime.now());

        Message savedMessage = messageRepository.save(message);

        // 更新会话的更新时间
        Conversation conversation = conversationOpt.get();
        conversation.setUpdatedAt(LocalDateTime.now());
        conversationRepository.save(conversation);

        // 推送实时消息给会话参与者
        pushRealTimeMessage(conversationId, savedMessage);

        return savedMessage;
    }

    /**
     * 标记会话为已读
     */
    public void markAsRead(Long conversationId, Long userId) {
        conversationParticipantRepository.updateLastReadAt(conversationId, userId, LocalDateTime.now());
    }

    private Long getOtherParticipantId(Conversation conversation, Long currentUserId) {
        List<ConversationParticipant> participants = conversationParticipantRepository
                .findByConversationId(conversation.getId());

        return participants.stream()
                .map(ConversationParticipant::getUserId)
                .filter(userId -> !userId.equals(currentUserId))
                .findFirst()
                .orElseThrow(() -> new RuntimeException("找不到会话的另一方参与者"));
    }

    private Message getLastMessage(Long conversationId) {
        Pageable pageable = PageRequest.of(0, 1, Sort.by(Sort.Direction.DESC, "createdAt"));
        List<Message> messages = messageRepository.findLatestMessages(conversationId, pageable);
        return messages.isEmpty() ? null : messages.get(0);
    }

    private Integer getUnreadCount(Long conversationId, Long userId) {
        Long count = conversationRepository.countUnreadMessages(conversationId, userId);
        return count != null ? count.intValue() : 0;
    }

    private void addParticipant(Conversation conversation, Long userId) {
        ConversationParticipant participant = new ConversationParticipant();
        participant.setConversation(conversation);
        participant.setUserId(userId);
        conversationParticipantRepository.save(participant);
    }

    /**
     * 推送实时消息给会话参与者
     */
    private void pushRealTimeMessage(Long conversationId, Message message) {
        try {
            // 获取会话的所有参与者
            List<ConversationParticipant> participants = conversationParticipantRepository
                    .findByConversationId(conversationId);

            // 提取参与者ID
            Long[] participantIds = participants.stream()
                    .map(ConversationParticipant::getUserId)
                    .toArray(Long[]::new);

            // 构建消息响应
            MessageResponse messageResponse = new MessageResponse(message);
            Optional<User> sender = userRepository.findById(message.getSenderId());
            if (sender.isPresent()) {
                User user = sender.get();
                messageResponse.setSenderName(user.getName());
                messageResponse.setSenderAvatar(user.getAvatar());
            }
            messageResponse.setIsMe(false); // 对于接收者来说，这不是自己发送的消息

            // 通过WebSocket推送消息
            chatWebSocketService.sendNewMessage(conversationId, messageResponse, participantIds);
        } catch (Exception e) {
            // WebSocket推送失败不影响消息发送，只记录错误
            e.printStackTrace();
        }
    }
}
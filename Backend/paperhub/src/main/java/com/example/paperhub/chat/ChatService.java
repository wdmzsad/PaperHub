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
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Service
public class ChatService {

    private static final Logger logger = LoggerFactory.getLogger(ChatService.class);

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
    @Transactional(readOnly = true)
    public List<ConversationResponse> getUserConversations(Long userId) {
        logger.info("获取用户会话列表: userId={}", userId);
        List<Conversation> conversations = conversationRepository.findByUserId(userId);
        logger.info("找到 {} 个会话", conversations.size());
        List<ConversationResponse> responses = new ArrayList<>();

        for (Conversation conversation : conversations) {
            logger.info("处理会话: conversationId={}", conversation.getId());
            // 获取会话的另一方用户信息
            Long otherUserId = getOtherParticipantId(conversation, userId);
            logger.info("会话的另一方用户ID: {}", otherUserId);

            if (otherUserId != null) {
                Optional<User> otherUser = userRepository.findById(otherUserId);
                logger.info("用户查询结果: {}", otherUser.isPresent());

                if (otherUser.isPresent()) {
                    User user = otherUser.get();

                    // 获取最后一条消息
                    Message lastMessage = getLastMessage(conversation.getId());
                    logger.info("最后一条消息: {}", lastMessage != null ? lastMessage.getId() : "null");

                    // 获取未读消息数
                    Integer unreadCount = getUnreadCount(conversation.getId(), userId);
                    logger.info("未读消息数: {}", unreadCount);

                    responses.add(new ConversationResponse(
                        conversation,
                        lastMessage,
                        unreadCount,
                        user.getName(),
                        user.getAvatar(),
                        false // TODO: 实现在线状态
                    ));
                    logger.info("成功添加会话响应");
                } else {
                    logger.warn("用户不存在: userId={}", otherUserId);
                }
            } else {
                logger.warn("无法找到会话的另一方用户: conversationId={}, currentUserId={}", conversation.getId(), userId);
            }
        }

        logger.info("返回 {} 个会话响应", responses.size());
        return responses;
    }

    /**
     * 创建或获取私聊会话
     */
    @Transactional
    public Conversation createOrGetPrivateConversation(Long currentUserId, Long targetUserId) {
        logger.info("开始创建或获取私聊会话: currentUserId={}, targetUserId={}", currentUserId, targetUserId);

        // 检查是否已存在私聊会话
        Optional<Conversation> existingConversation = conversationRepository
                .findPrivateConversationBetweenUsers(currentUserId, targetUserId);

        if (existingConversation.isPresent()) {
            logger.info("找到已存在的会话: {}", existingConversation.get().getId());
            return existingConversation.get();
        }

        logger.info("创建新的私聊会话");
        // 创建新的私聊会话
        Conversation conversation = new Conversation();
        conversation.setType(ConversationType.PRIVATE);
        conversation.setCreatedAt(LocalDateTime.now());
        conversation.setUpdatedAt(LocalDateTime.now());
        conversation = conversationRepository.save(conversation);
        logger.info("新会话创建成功: {}", conversation.getId());

        // 添加参与者
        addParticipant(conversation, currentUserId);
        addParticipant(conversation, targetUserId);
        logger.info("参与者添加完成");

        return conversation;
    }

    /**
     * 获取会话消息
     */
    @Transactional
    public Page<MessageResponse> getConversationMessages(Long conversationId, Long userId, int page, int size) {
        // 验证用户是否在会话中
        if (!conversationParticipantRepository.existsByConversationIdAndUserId(conversationId, userId)) {
            // 返回空页面而不是抛出异常
            return Page.empty();
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
    @Transactional
    public Message sendMessage(Long conversationId, Long senderId, String content, MessageType type,
                              String fileUrl, String fileName, Long fileSize) {
        // 验证用户是否在会话中
        if (!conversationParticipantRepository.existsByConversationIdAndUserId(conversationId, senderId)) {
            return null;
        }

        Optional<Conversation> conversationOpt = conversationRepository.findById(conversationId);
        if (conversationOpt.isEmpty()) {
            return null;
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
     * 发送带媒体文件的消息
     */
    @Transactional
    public Message sendMessageWithMedia(Long conversationId, Long senderId, String content,
                                       MessageType type, List<String> mediaUrls) {
        if (!conversationParticipantRepository.existsByConversationIdAndUserId(conversationId, senderId)) {
            return null;
        }

        Optional<Conversation> conversationOpt = conversationRepository.findById(conversationId);
        if (conversationOpt.isEmpty()) {
            return null;
        }

        Message message = new Message();
        message.setConversation(conversationOpt.get());
        message.setSenderId(senderId);
        message.setContent(content);
        message.setType(type);
        message.setMediaUrls(mediaUrls != null ? mediaUrls : new ArrayList<>());
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
    @Transactional
    public void markAsRead(Long conversationId, Long userId) {
        conversationParticipantRepository.updateLastReadAt(conversationId, userId, LocalDateTime.now());
    }

    private Long getOtherParticipantId(Conversation conversation, Long currentUserId) {
        List<ConversationParticipant> participants = conversationParticipantRepository
                .findByConversationId(conversation.getId());
        logger.info("会话参与者数量: {}", participants.size());

        for (ConversationParticipant participant : participants) {
            logger.info("参与者: userId={}, currentUserId={}", participant.getUserId(), currentUserId);
        }

        Long otherUserId = participants.stream()
                .map(ConversationParticipant::getUserId)
                .filter(userId -> userId != null && !userId.equals(currentUserId))
                .findFirst()
                .orElse(null); // 返回null而不是抛出异常

        logger.info("找到的另一方用户ID: {}", otherUserId);
        return otherUserId;
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
        participant.setJoinedAt(LocalDateTime.now()); // Explicitly set joinedAt
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
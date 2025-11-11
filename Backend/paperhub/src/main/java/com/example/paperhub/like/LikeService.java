package com.example.paperhub.like;

import com.example.paperhub.auth.User;
import com.example.paperhub.comment.Comment;
import com.example.paperhub.comment.CommentRepository;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import com.example.paperhub.post.PostService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

@Service
public class LikeService {
    private final PostLikeRepository postLikeRepository;
    private final CommentLikeRepository commentLikeRepository;
    private final PostRepository postRepository;
    private final CommentRepository commentRepository;
    private final PostService postService;

    public LikeService(
            PostLikeRepository postLikeRepository,
            CommentLikeRepository commentLikeRepository,
            PostRepository postRepository,
            CommentRepository commentRepository,
            PostService postService) {
        this.postLikeRepository = postLikeRepository;
        this.commentLikeRepository = commentLikeRepository;
        this.postRepository = postRepository;
        this.commentRepository = commentRepository;
        this.postService = postService;
    }

    /**
     * 点赞帖子
     */
    @Transactional
    public boolean likePost(Long postId, User user) {
        Post post = postRepository.findById(postId)
            .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        
        Optional<PostLike> existingLike = postLikeRepository.findByPostAndUser(post, user);
        if (existingLike.isPresent()) {
            return false; // 已经点赞过
        }

        PostLike like = new PostLike();
        like.setPost(post);
        like.setUser(user);
        postLikeRepository.save(like);
        
        postService.incrementLikesCount(postId);
        return true;
    }

    /**
     * 取消点赞帖子
     */
    @Transactional
    public boolean unlikePost(Long postId, User user) {
        Post post = postRepository.findById(postId)
            .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        
        Optional<PostLike> existingLike = postLikeRepository.findByPostAndUser(post, user);
        if (existingLike.isEmpty()) {
            return false; // 未点赞
        }

        postLikeRepository.delete(existingLike.get());
        postService.decrementLikesCount(postId);
        return true;
    }

    /**
     * 检查用户是否已点赞帖子
     */
    public boolean isPostLiked(Long postId, Long userId) {
        return postLikeRepository.existsByPostIdAndUserId(postId, userId);
    }

    /**
     * 获取帖子的点赞数
     */
    public long getPostLikesCount(Long postId) {
        return postLikeRepository.countByPostId(postId);
    }

    /**
     * 点赞评论
     */
    @Transactional
    public boolean likeComment(Long commentId, User user) {
        Comment comment = commentRepository.findById(commentId)
            .orElseThrow(() -> new IllegalArgumentException("评论不存在"));
        
        Optional<CommentLike> existingLike = commentLikeRepository.findByCommentAndUser(comment, user);
        if (existingLike.isPresent()) {
            return false; // 已经点赞过
        }

        CommentLike like = new CommentLike();
        like.setComment(comment);
        like.setUser(user);
        commentLikeRepository.save(like);
        
        comment.setLikesCount(comment.getLikesCount() + 1);
        commentRepository.save(comment);
        return true;
    }

    /**
     * 取消点赞评论
     */
    @Transactional
    public boolean unlikeComment(Long commentId, User user) {
        Comment comment = commentRepository.findById(commentId)
            .orElseThrow(() -> new IllegalArgumentException("评论不存在"));
        
        Optional<CommentLike> existingLike = commentLikeRepository.findByCommentAndUser(comment, user);
        if (existingLike.isEmpty()) {
            return false; // 未点赞
        }

        commentLikeRepository.delete(existingLike.get());
        if (comment.getLikesCount() > 0) {
            comment.setLikesCount(comment.getLikesCount() - 1);
            commentRepository.save(comment);
        }
        return true;
    }

    /**
     * 检查用户是否已点赞评论
     */
    public boolean isCommentLiked(Long commentId, Long userId) {
        return commentLikeRepository.existsByCommentIdAndUserId(commentId, userId);
    }

    /**
     * 获取评论的点赞数
     */
    public long getCommentLikesCount(Long commentId) {
        return commentLikeRepository.countByCommentId(commentId);
    }
}


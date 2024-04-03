package org.swordsmen.openaiproxy.channel.core;

import com.fasterxml.jackson.annotation.JsonIgnore;
import lombok.Getter;
import lombok.Setter;

import java.io.Serial;
import java.io.Serializable;

/**
 * @author JLT
 * Create by 2024/4/2
 */
@Getter
public class ChatMessage implements Serializable {

    @Serial
    private static final long serialVersionUID = 6649447496766830661L;

    private ChatMessage() {

    }

    @Setter
    private ChatRole role;

    @Setter
    private String content;

    @JsonIgnore
    private Boolean allowDeleted;

    public static ChatMessage build(ChatRole role, String content) {
        ChatMessage chatMessage = new ChatMessage();
        chatMessage.role = role;
        chatMessage.content = content;
        chatMessage.allowDeleted = true;
        return chatMessage;
    }

    public static ChatMessage buildSystemMsg(String content) {
        ChatMessage chatMessage = new ChatMessage();
        chatMessage.role = ChatRole.SYSTEM;
        chatMessage.content = content;
        chatMessage.allowDeleted = false;
        return chatMessage;
    }

}

package org.swordsmen.openaiproxy.channel.core;

import lombok.Data;

/**
 * @author JLT
 * Create by 2024/4/2
 */
@Data
public class ChatResponse {

    private String text;

    private ResponseStatus status;

    public static ChatResponse error() {
        ChatResponse response = new ChatResponse();
        response.setStatus(ResponseStatus.ERROR);
        return response;
    }

}

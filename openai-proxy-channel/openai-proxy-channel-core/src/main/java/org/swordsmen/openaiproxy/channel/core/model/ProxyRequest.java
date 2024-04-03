package org.swordsmen.openaiproxy.channel.core.model;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;
import org.swordsmen.openaiproxy.channel.core.ChatMessage;

import java.io.Serial;
import java.io.Serializable;
import java.util.List;

/**
 * @author JLT
 * Create by 2024/4/3
 */
@Data
public class ProxyRequest implements Serializable {

    @Serial
    private static final long serialVersionUID = -5632025388563515096L;

    private List<ChatMessage> messages;
    private Boolean stream;
    private BotType botType;
    private Double temperature;
    @JsonProperty("top_p")
    private Double topP;
    private String model;
    @JsonProperty("frequency_penalty")
    private Double frequencyPenalty;
    @JsonProperty("presence_penalty")
    private Double presencePenalty;
    private List<Tool> tools;

}

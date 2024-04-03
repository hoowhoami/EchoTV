package org.swordsmen.openaiproxy.channel.core.model;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Data;

import java.io.Serial;
import java.io.Serializable;

/**
 * @author JLT
 * Create by 2024/4/3
 */
@Data
public class Choices implements Serializable {

    @Serial
    private static final long serialVersionUID = 6710332500939690765L;

    private int index;

    /**
     * stream为false时返回
     */
    private Message message;

    /**
     * stream为true时返回
     */
    private Message delta;

    @JsonProperty("finish_reason")
    private String finishReason;

}

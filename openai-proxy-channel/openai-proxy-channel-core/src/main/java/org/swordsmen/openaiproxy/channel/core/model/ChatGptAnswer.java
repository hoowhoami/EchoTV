package org.swordsmen.openaiproxy.channel.core.model;

import lombok.Data;

import java.io.Serial;
import java.io.Serializable;
import java.util.List;

/**
 * @author JLT
 * Create by 2024/4/3
 */
@Data
public class ChatGptAnswer implements Serializable {

    @Serial
    private static final long serialVersionUID = -9004175039406872327L;

    private String id;
    private String object;
    private Long created;
    private String model;

    private List<Choices> choices;

}

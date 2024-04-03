package org.swordsmen.openaiproxy.channel.core.model;

import lombok.Data;

/**
 * @author JLT
 * Create by 2024/4/3
 */
@Data
public class Tool {
    private String type;
    private Function function;
}

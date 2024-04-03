package org.swordsmen.openaiproxy.channel.core.model;

import lombok.Data;

/**
 * @author JLT
 * Create by 2024/4/3
 */
@Data
public class Function {

    private String url;
    private String name;
    private String description;
    private Parameters parameters;

}

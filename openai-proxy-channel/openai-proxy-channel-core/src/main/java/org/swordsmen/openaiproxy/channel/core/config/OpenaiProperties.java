package org.swordsmen.openaiproxy.channel.core.config;

import lombok.Data;

/**
 * @author JLT
 * Create by 2024/4/3
 */
@Data
public class OpenaiProperties {

    private boolean enabled;

    private String baseUrl = "https://api.openai.com";

    private String apiKey;

}

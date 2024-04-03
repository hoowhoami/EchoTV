package org.swordsmen.openaiproxy.channel.core.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.NestedConfigurationProperty;

/**
 * @author JLT
 * Create by 2024/4/2
 */
@ConfigurationProperties(prefix = "proxy")
@Data
public class ProxyProperties {

    private String keyPrefix = "gpt-proxy";

    private boolean printLog = true;

    private String auth = "whoami";

    @NestedConfigurationProperty
    private OpenaiProperties openai = new OpenaiProperties();

}

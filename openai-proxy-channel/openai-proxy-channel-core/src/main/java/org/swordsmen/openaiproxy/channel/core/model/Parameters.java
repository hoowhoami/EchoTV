package org.swordsmen.openaiproxy.channel.core.model;

import lombok.Data;

import java.util.List;
import java.util.Map;

/**
 * @author JLT
 * Create by 2024/4/3
 */
@Data
public class Parameters {

    private String type;
    private Map<String, Map<String, Object>> properties;
    private List<String> required;

}

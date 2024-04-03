package org.swordsmen.openaiproxy.channel.core.model;

import lombok.Data;

import java.io.Serial;
import java.io.Serializable;

/**
 * @author JLT
 * Create by 2024/4/3
 */
@Data
public class Message implements Serializable {

    @Serial
    private static final long serialVersionUID = -4257930390683997645L;

    private String role;
    private String content;

}

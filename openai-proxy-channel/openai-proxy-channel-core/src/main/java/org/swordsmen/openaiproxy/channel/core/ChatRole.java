package org.swordsmen.openaiproxy.channel.core;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;
import lombok.Getter;

/**
 * @author JLT
 * Create by 2024/4/3
 */
@Getter
public enum ChatRole {

    SYSTEM("system", "系统"),
    USER("user", "用户"),
    ASSISTANT("assistant", "助手"),

    ;

    @JsonValue
    private final String code;
    private final String desc;
    ChatRole(String code, String desc) {
        this.code = code;
        this.desc = desc;
    }

    @JsonCreator
    public static ChatRole getByCode(String code) {
        for (ChatRole item : ChatRole.values()) {
            if (item.getCode().equals(code)) {
                return item;
            }
        }
        return null;
    }

}

package org.swordsmen.openaiproxy.channel.core.model;

import lombok.Getter;

/**
 * @author JLT
 * Create by 2024/4/3
 */
@Getter
public enum BotType {

    BITO("bito"),
    OPENAI("openai"),
    ALI_GPT("ali"),
    XFXH_GPT("xfxh"),
    GEMINI_GPT("gemini"),
    COPILOT("copilot"),
    DOUBLE("double"),
    KIMI("kimi"),
    GLM("glm"),
    // 轮询
    ALL("all"),

    ;

    private final String name;

    BotType(String name) {
        this.name = name;
    }

    public static BotType of(String name) {
        for (BotType value : BotType.values()) {
            if (value.name.equals(name)) {
                return value;
            }
        }
        return null;
    }

}

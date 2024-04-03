package org.swordsmen.openaiproxy.channel.core;

import lombok.Getter;

/**
 * @author JLT
 * Create by 2024/4/3
 */
@Getter
public enum GptModel {

    GPT_35_TURBO("gpt-3.5-turbo"),
    GPT_35_TURBO_16K("gpt-3.5-turbo-16k"),
    GPT_35_TURBO_0613("gpt-3.5-turbo-0613"),
    GPT_35_TURBO_16K_0613("gpt-3.5-turbo-16k-0613"),
    GPT_4("gpt-4"),
    GPT_4_0613("gpt-4-0613"),
    GPT_4_32K("gpt-4-32k"),
    GPT_4_32K_0613("gpt-4-32k-0613"),

    ;

    private final String model;

    GptModel(String model) {
        this.model = model;
    }

    public GptModel of(String model) {
        for (GptModel value : values()) {
            if (value.getModel().equals(model)) {
                return value;
            }
        }
        return GptModel.GPT_35_TURBO_0613;
    }

}

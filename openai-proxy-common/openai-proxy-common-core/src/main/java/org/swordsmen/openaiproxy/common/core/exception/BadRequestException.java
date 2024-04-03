package org.swordsmen.openaiproxy.common.core.exception;

import java.io.Serial;

/**
 * @author JLT
 * Create by 2024/4/3
 */
public class BadRequestException extends RuntimeException {

    @Serial
    private static final long serialVersionUID = 7215220870004033238L;

    public BadRequestException(String msg) {
        super(msg);
    }

    public BadRequestException(String msg, Throwable e) {
        super(msg, e);
    }

}

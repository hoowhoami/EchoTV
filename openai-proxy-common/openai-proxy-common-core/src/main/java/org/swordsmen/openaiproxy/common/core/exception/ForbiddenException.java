package org.swordsmen.openaiproxy.common.core.exception;

import java.io.Serial;

/**
 * @author JLT
 * Create by 2024/4/3
 */
public class ForbiddenException extends RuntimeException {

    @Serial
    private static final long serialVersionUID = 3669374777904104076L;

    public ForbiddenException(String msg) {
        super(msg);
    }

    public ForbiddenException(String msg, Throwable e) {
        super(msg, e);
    }

}

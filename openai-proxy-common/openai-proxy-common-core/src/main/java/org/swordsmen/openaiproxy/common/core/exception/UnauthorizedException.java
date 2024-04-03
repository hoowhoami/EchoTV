package org.swordsmen.openaiproxy.common.core.exception;

import java.io.Serial;

/**
 * @author JLT
 * Create by 2024/4/3
 */
public class UnauthorizedException extends RuntimeException {

    @Serial
    private static final long serialVersionUID = 3096396920351651037L;

    public UnauthorizedException(String msg) {
        super(msg);
    }

    public UnauthorizedException(String msg, Throwable e) {
        super(msg, e);
    }

}

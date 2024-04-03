package org.swordsmen.openaiproxy.server.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ServerWebExchange;
import org.swordsmen.openaiproxy.common.core.exception.BadRequestException;
import org.swordsmen.openaiproxy.common.core.exception.ForbiddenException;
import org.swordsmen.openaiproxy.common.core.exception.UnauthorizedException;

/**
 * @author JLT
 * Create by 2024/4/3
 */
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(BadRequestException.class)
    public Response<Void> badRequest(BadRequestException e, ServerWebExchange exchange) {
        log.error("Business exception", e);
        exchange.getResponse().setStatusCode(HttpStatus.BAD_REQUEST);
        return Response.error(400, e.getMessage());
    }

    @ExceptionHandler(UnauthorizedException.class)
    public Response<Void> unauthorized(UnauthorizedException e, ServerWebExchange exchange) {
        log.error("Business exception", e);
        exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
        return Response.error(401, e.getMessage());
    }

    @ExceptionHandler(ForbiddenException.class)
    public Response<Void> forbidden(ForbiddenException e, ServerWebExchange exchange) {
        log.error("Business exception", e);
        exchange.getResponse().setStatusCode(HttpStatus.FORBIDDEN);
        return Response.error(403, e.getMessage());
    }

    @ExceptionHandler(RuntimeException.class)
    public Response<Void> business(RuntimeException e) {
        log.error("Business exception", e);
        return Response.error(e.getMessage());
    }

    @ExceptionHandler(Throwable.class)
    public Response<Void> exception(Throwable e) {
        log.error("System exception", e);
        return Response.error(500, "System error");
    }

}

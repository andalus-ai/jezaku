package tech.kayys.jezaku.http;

import jakarta.ws.rs.container.ContainerRequestContext;
import jakarta.ws.rs.container.ContainerRequestFilter;
import jakarta.ws.rs.container.ContainerResponseContext;
import jakarta.ws.rs.container.ContainerResponseFilter;
import jakarta.ws.rs.ext.Provider;

import java.util.UUID;

@Provider
public class RequestIdFilter implements ContainerRequestFilter, ContainerResponseFilter {
    public static final String HEADER = "X-Request-Id";
    public static final String PROPERTY = "jezaku.requestId";

    @Override
    public void filter(ContainerRequestContext requestContext) {
        requestContext.setProperty(PROPERTY, requestId(requestContext.getHeaderString(HEADER)));
    }

    @Override
    public void filter(ContainerRequestContext requestContext, ContainerResponseContext responseContext) {
        responseContext.getHeaders().putSingle(HEADER, requestId(requestContext.getProperty(PROPERTY)));
    }

    private String requestId(Object value) {
        if (value instanceof String text && !text.isBlank()) {
            return text;
        }
        return UUID.randomUUID().toString();
    }
}

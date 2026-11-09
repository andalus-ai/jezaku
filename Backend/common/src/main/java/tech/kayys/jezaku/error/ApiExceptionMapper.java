package tech.kayys.jezaku.error;

import jakarta.ws.rs.WebApplicationException;
import jakarta.ws.rs.container.ContainerRequestContext;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.UriInfo;
import jakarta.ws.rs.ext.ExceptionMapper;
import jakarta.ws.rs.ext.Provider;
import org.jboss.logging.Logger;
import tech.kayys.jezaku.http.RequestIdFilter;

import java.time.Instant;

@Provider
public class ApiExceptionMapper implements ExceptionMapper<Throwable> {
    private static final Logger LOG = Logger.getLogger(ApiExceptionMapper.class);
    private static final String RETRY_AFTER_HEADER = "Retry-After";

    @Context
    UriInfo uriInfo;
    @Context
    ContainerRequestContext requestContext;

    @Override
    public Response toResponse(Throwable exception) {
        int status = status(exception);
        if (status >= 500) {
            LOG.errorf(exception, "Unhandled request failure requestId=%s path=%s", requestId(), path());
        }
        ApiError error = new ApiError(
                code(status),
                message(exception, status),
                status,
                path(),
                requestId(),
                Instant.now());
        Response.ResponseBuilder response = Response.status(status)
                .type(MediaType.APPLICATION_JSON_TYPE)
                .entity(error);
        copyRetryAfter(exception, response);
        return response.build();
    }

    private int status(Throwable exception) {
        if (exception instanceof WebApplicationException webApplicationException
                && webApplicationException.getResponse() != null) {
            return webApplicationException.getResponse().getStatus();
        }
        return Response.Status.INTERNAL_SERVER_ERROR.getStatusCode();
    }

    private String code(int status) {
        return switch (status) {
            case 400 -> "BAD_REQUEST";
            case 401 -> "UNAUTHORIZED";
            case 403 -> "FORBIDDEN";
            case 404 -> "NOT_FOUND";
            case 409 -> "CONFLICT";
            case 415 -> "UNSUPPORTED_MEDIA_TYPE";
            default -> status >= 500 ? "INTERNAL_ERROR" : "REQUEST_ERROR";
        };
    }

    private String message(Throwable exception, int status) {
        if (status >= 500) {
            return "Unexpected server error";
        }
        String message = exception.getMessage();
        return message == null || message.isBlank() ? code(status) : message;
    }

    private void copyRetryAfter(Throwable exception, Response.ResponseBuilder response) {
        if (exception instanceof WebApplicationException webApplicationException
                && webApplicationException.getResponse() != null) {
            String retryAfter = webApplicationException.getResponse().getHeaderString(RETRY_AFTER_HEADER);
            if (retryAfter != null && !retryAfter.isBlank()) {
                response.header(RETRY_AFTER_HEADER, retryAfter);
            }
        }
    }

    private String path() {
        return uriInfo == null ? "" : uriInfo.getPath();
    }

    private String requestId() {
        Object value = requestContext == null ? null : requestContext.getProperty(RequestIdFilter.PROPERTY);
        return value instanceof String text ? text : "";
    }
}

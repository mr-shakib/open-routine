"""Domain exceptions and the handlers that turn them into HTTP responses."""

from __future__ import annotations

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse


class OpenRoutineError(Exception):
    """Base class for expected, reportable failures."""

    status_code: int = status.HTTP_400_BAD_REQUEST
    code: str = "error"

    def __init__(self, message: str, *, detail: object | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.detail = detail


class NotFoundError(OpenRoutineError):
    status_code = status.HTTP_404_NOT_FOUND
    code = "not_found"


class NoActiveRoutineError(NotFoundError):
    code = "no_active_routine"

    def __init__(self, department: str) -> None:
        super().__init__(
            f"No active routine for department {department!r}. Ingest one first.",
            detail={"department": department},
        )


class ValidationError(OpenRoutineError):
    status_code = 422
    code = "validation_error"


class IngestionError(OpenRoutineError):
    """Raised when a spreadsheet cannot be trusted.

    Ingestion fails loudly rather than importing a partial routine: a routine
    that is silently missing classes is worse than no routine at all.
    """

    status_code = 422
    code = "ingestion_error"


class AuthError(OpenRoutineError):
    status_code = status.HTTP_401_UNAUTHORIZED
    code = "unauthorized"


def register_exception_handlers(app: FastAPI) -> None:
    async def handle(request: Request, exc: Exception) -> JSONResponse:  # noqa: ARG001
        assert isinstance(exc, OpenRoutineError)
        body: dict[str, object] = {"error": {"code": exc.code, "message": exc.message}}
        if exc.detail is not None:
            body["error"]["detail"] = exc.detail  # type: ignore[index]
        return JSONResponse(status_code=exc.status_code, content=body)

    app.add_exception_handler(OpenRoutineError, handle)

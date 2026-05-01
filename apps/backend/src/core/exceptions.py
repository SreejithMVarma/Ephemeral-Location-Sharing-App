class DomainError(Exception):
    code = "domain_error"
    status_code = 400

    def __init__(self, message: str):
        super().__init__(message)
        self.message = message


class NotFoundError(DomainError):
    code = "not_found"
    status_code = 404


class UnauthorizedError(DomainError):
    code = "unauthorized"
    status_code = 401

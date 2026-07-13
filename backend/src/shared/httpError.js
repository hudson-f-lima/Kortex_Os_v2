export class HttpError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.name = 'HttpError';
    this.status = status;
    this.code = code;
    this.details = details;
  }

  static unauthorized(code, message, details) {
    return new HttpError(401, code, message, details);
  }

  static forbidden(code, message, details) {
    return new HttpError(403, code, message, details);
  }

  static badRequest(code, message, details) {
    return new HttpError(400, code, message, details);
  }

  static notFound(code, message, details) {
    return new HttpError(404, code, message, details);
  }

  static conflict(code, message, details) {
    return new HttpError(409, code, message, details);
  }
}

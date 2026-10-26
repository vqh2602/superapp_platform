class ActionResult {
  final bool success;
  final dynamic data;
  final String? errorCode;
  final String? errorMessage;

  const ActionResult.ok(this.data)
      : success = true,
        errorCode = null,
        errorMessage = null;

  const ActionResult.fail(this.errorCode, this.errorMessage)
      : success = false,
        data = null;
}

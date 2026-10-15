import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/errors/error_messages.dart';

String authErrorMessage(Object error) {
  if (error is ApiException) {
    return messageForCode(error.code);
  }
  if (error is NetworkException) {
    return error.message;
  }
  if (error is UnauthorizedException) {
    return error.message;
  }
  return messageForCode('INTERNAL_ERROR');
}

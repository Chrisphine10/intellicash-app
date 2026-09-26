import 'dart:async';
import 'dart:io';

import '../network/api_exception.dart';
import 'domain_exception.dart';

/// What a person reads when something fails.
///
/// The app's own errors ([ApiException], [DomainException]) already carry a
/// sentence written for the treasurer. Anything else - a dropped connection,
/// a parser, the framework - used to reach the screen as its raw text
/// ("SocketException: Failed host lookup", "FormatException: ..."), which
/// reads like a crash and says nothing about what to do.
String userMessage(Object error) {
  if (error is ApiException) return error.message;
  if (error is DomainException) return error.message;
  if (error is SocketException || error is TimeoutException || error is HttpException) {
    return 'Could not reach IntelliCash. Check your internet connection and try again.';
  }
  return 'Something went wrong. Please try again. If it keeps happening, contact IntelliCash support.';
}

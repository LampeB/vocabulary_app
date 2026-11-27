/// Session arrival can precede the profile response. The splash gate owns
/// restoring account data before any authenticated landing page is shown.
String? authRedirect({required bool isSignedIn, required String location}) {
  final public =
      location == '/splash' || location == '/welcome' || location == '/auth';
  if (!isSignedIn && !public) {
    return '/welcome';
  }
  if (isSignedIn && (location == '/welcome' || location == '/auth')) {
    return '/splash';
  }
  return null;
}

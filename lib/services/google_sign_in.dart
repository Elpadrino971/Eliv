import 'package:artist/Global/global.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

FirebaseAuth fAuth = FirebaseAuth.instance;
User? user;

// It is highly recommended to initialize GoogleSignIn once at app startup
// (e.g., in main() or a dedicated service). This helper ensures it's done.
bool _isGoogleSignInInitialized = false;
Future<void> _ensureGoogleSignInInitialized() async {
  if (!_isGoogleSignInInitialized) {
    try {
      // You might need to pass clientId and serverClientId here if your app requires them
      // for specific Google API access or advanced configurations.
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '124121302377-0tvst2pvbl7rs0t3cfvao4pnuvasasac.apps.googleusercontent.com',
      );
      // await GoogleSignIn.instance.initialize();
      _isGoogleSignInInitialized = true;
    } catch (e) {
      myPrint('ERROR: Failed to initialize Google Sign-In: $e');
      rethrow; // Propagate the initialization failure
    }
  }
}

Future<User?> signInWithGoogle() async {
  try {
    // Step 1: Ensure GoogleSignIn is initialized asynchronously.
    await _ensureGoogleSignInInitialized();

    // Step 2: Access the GoogleSignIn singleton instance.
    final GoogleSignIn googleSignIn = GoogleSignIn.instance;

    // Step 3: Trigger the authentication flow using authenticate().
    // This method now throws exceptions instead of returning null for cancellation/errors.
    // Specify required scopes. 'email' is usually sufficient for Firebase Auth.
    // ignore: unnecessary_nullable_for_final_variable_declarations
    final GoogleSignInAccount? googleSignInAccount = await googleSignIn
        .authenticate(scopeHint: ['email']);

    // Handle user cancellation or no account selected.
    if (googleSignInAccount == null) {
      myPrint('Google Sign-In cancelled by user or no account selected.');
      return null;
    }

    // Step 4: Obtain the authentication details synchronously from the GoogleSignInAccount.
    // IMPORTANT: In google_sign_in v7.x.x, GoogleSignInAuthentication ONLY contains idToken.
    // The accessToken is NOT directly available here.
    final GoogleSignInAuthentication googleSignInAuthentication =
        googleSignInAccount.authentication;

    // Step 5: Create a new Firebase AuthCredential using the idToken.
    // For basic Firebase authentication, idToken is sufficient.
    // The 'accessToken' parameter can be omitted or passed as null if not available.
    final AuthCredential credential = GoogleAuthProvider.credential(
      idToken: googleSignInAuthentication.idToken,
      // accessToken: googleSignInAuthentication.accessToken, // This line causes the error in v7.x.x
      // If you need an accessToken for other Google API calls, you would obtain it
      // via googleSignInAccount.authorizationClient.authorizeScopes() separately.
      accessToken:
          null, // Explicitly pass null if the parameter is required but not available
    );

    // Step 6: Sign in with the credential to Firebase.
    UserCredential result = await fAuth.signInWithCredential(credential);
    User? userValue = result.user;

    if (userValue != null) {
      user = userValue;
    }
    return user;
  } on GoogleSignInException catch (e) {
    // Handle specific Google Sign-In errors, including user cancellation.
    myPrint(
      'Google Sign In error: Code: ${e.code.name}, Description: ${e.description}, Details: ${e.details}',
    );
    return null;
  } catch (e) {
    // Catch any other unexpected errors during the sign-in process.
    myPrint('Unexpected error during Google Sign-In: $e');
    return null;
  }
}

// Example of how to get an accessToken for other Google API calls if needed
// This is separate from the initial Firebase authentication flow.
Future<String?> getGoogleAccessTokenForApi(
  GoogleSignInAccount userAccount,
  List<String> scopes,
) async {
  try {
    // Ensure GoogleSignIn is initialized
    await _ensureGoogleSignInInitialized();

    final GoogleSignInClientAuthorization? authorization = await userAccount
        .authorizationClient
        .authorizationForScopes(scopes);

    if (authorization == null) {
      // User has not granted these scopes, or authorization expired.
      // You might need to prompt the user to authorize these scopes.
      myPrint('Authorization for scopes $scopes not granted or expired.');
      return null;
    }
    return authorization.accessToken;
  } on GoogleSignInException catch (e) {
    myPrint(
      'Error getting access token for API: ${e.code.name}, ${e.description}',
    );
    return null;
  } catch (e) {
    myPrint('Unexpected error getting access token for API: $e');
    return null;
  }
}

import 'package:artist/Global/global.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Résultat d'une connexion Google réussie côté appareil.
/// Le backend (/api/social-login) vérifie lui-même l'id_token auprès de
/// Google : on n'a donc PAS besoin de passer par Firebase Auth (qui exigeait
/// en plus que le fournisseur Google soit activé dans la console Firebase,
/// une source d'échec silencieux de plus).
class GoogleLoginResult {
  final String email;
  final String name;
  final String? idToken;
  const GoogleLoginResult({
    required this.email,
    required this.name,
    required this.idToken,
  });
}

/// Dernier id_token Google (audience = serverClientId ci-dessous). Envoyé au
/// backend pour vérifier la connexion sociale côté serveur (social_auth.js).
String? googleIdToken;

/// Raison du dernier échec (code court), null si l'utilisateur a simplement
/// annulé. Sert au message affiché à l'écran pour diagnostiquer sans logs.
String? googleLastError;

/// Client OAuth "Web" du projet Firebase vybzzz-app. Sert d'audience à
/// l'id_token sur Android (Credential Manager) et de serverClientId sur iOS.
const String kGoogleServerClientId =
    '284585255358-raknf147buj3vn5ch4ia67u8742fhgt2.apps.googleusercontent.com';

bool _isGoogleSignInInitialized = false;
Future<void> _ensureGoogleSignInInitialized() async {
  if (_isGoogleSignInInitialized) return;
  await GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId);
  _isGoogleSignInInitialized = true;
}

/// Ouvre le sélecteur de compte Google et renvoie email / nom / id_token.
/// Renvoie null si annulé ou en erreur (voir [googleLastError]).
Future<GoogleLoginResult?> signInWithGoogle() async {
  googleLastError = null;
  googleIdToken = null;
  try {
    await _ensureGoogleSignInInitialized();
    final GoogleSignInAccount account = await GoogleSignIn.instance
        .authenticate(scopeHint: const ['email']);

    googleIdToken = account.authentication.idToken;
    if (googleIdToken == null) {
      // Sans id_token le backend refusera : on le signale clairement.
      googleLastError = 'no_id_token';
      myPrint('Google Sign-In: aucun id_token renvoyé (SHA-1 / client OAuth ?)');
      return null;
    }
    return GoogleLoginResult(
      email: account.email,
      name: (account.displayName ?? '').trim().isEmpty
          ? account.email.split('@').first
          : account.displayName!.trim(),
      idToken: googleIdToken,
    );
  } on GoogleSignInException catch (e) {
    myPrint(
      'Google Sign In error: ${e.code.name} — ${e.description} — ${e.details}',
    );
    // Annulation volontaire : pas une erreur, pas de message.
    if (e.code == GoogleSignInExceptionCode.canceled) return null;
    googleLastError = e.code.name;
    return null;
  } catch (e) {
    myPrint('Unexpected error during Google Sign-In: $e');
    googleLastError = 'unexpected';
    return null;
  }
}

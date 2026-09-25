import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

abstract class AuthService {
  User? get currentUser;
  Stream<User?> get authStateChanges;
  
  Future<User?> signInWithEmail(String email, String password);
  Future<User?> signUpWithEmail(String email, String password);
  Future<User?> signInWithGoogle();
  Future<User?> signInWithApple();
  Future<User?> signInAnonymously(); // Guest Login
  Future<void> signOut();
}

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  @override
  Future<User?> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user;
  }

  @override
  Future<User?> signUpWithEmail(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user;
  }

  @override
  Future<User?> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn.instance;
    try {
      await googleSignIn.initialize();
    } catch (_) {}

    final GoogleSignInAccount googleUser = await googleSignIn.authenticate();
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: null,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential = await _auth.signInWithCredential(credential);
    return userCredential.user;
  }

  @override
  Future<User?> signInWithApple() async {
    final AuthorizationCredentialAppleID appleCredential = 
        await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final OAuthProvider oAuthProvider = OAuthProvider("apple.com");
    final AuthCredential credential = oAuthProvider.credential(
      idToken: appleCredential.identityToken,
      rawNonce: null,
    );

    final UserCredential userCredential = await _auth.signInWithCredential(credential);
    return userCredential.user;
  }

  @override
  Future<User?> signInAnonymously() async {
    final UserCredential userCredential = await _auth.signInAnonymously();
    return userCredential.user;
  }

  @override
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
  }
}

// Fallback Mock service if Firebase is not initialized yet
class MockAuthService implements AuthService {
  User? _mockUser;
  
  @override
  User? get currentUser => _mockUser;

  @override
  Stream<User?> get authStateChanges => Stream.value(_mockUser);

  @override
  Future<User?> signInWithEmail(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _mockUser;
  }

  @override
  Future<User?> signUpWithEmail(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _mockUser;
  }

  @override
  Future<User?> signInWithGoogle() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _mockUser;
  }

  @override
  Future<User?> signInWithApple() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _mockUser;
  }

  @override
  Future<User?> signInAnonymously() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _mockUser;
  }

  @override
  Future<void> signOut() async {
    _mockUser = null;
  }
}

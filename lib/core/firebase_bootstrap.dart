import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../config/env.dart';

/// Name of the secondary FirebaseApp used only for creating other people's
/// accounts. See [secondaryApp].
const String _secondaryAppName = 'famliSecondary';

Future<void> initFirebase() async {
  await Firebase.initializeApp(options: Env.firebaseOptions);

  if (!Env.useEmulators) return;

  final host = Env.emulatorHost;
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
}

/// A parent creating a child account cannot call
/// createUserWithEmailAndPassword on the default FirebaseApp: that call signs
/// in as the newly created user, silently replacing the parent's own session.
///
/// Creating the account on a separate FirebaseApp keeps the default app's
/// session untouched. The caller must sign this app out afterwards — see
/// [createAccountWithoutSignIn], which does both.
Future<FirebaseApp> secondaryApp() async {
  try {
    return Firebase.app(_secondaryAppName);
  } on FirebaseException {
    return Firebase.initializeApp(
      name: _secondaryAppName,
      options: Env.firebaseOptions,
    );
  }
}

/// Creates an Auth account without disturbing the current user's session,
/// returning the new account's uid.
Future<String> createAccountWithoutSignIn({
  required String email,
  required String password,
}) async {
  final app = await secondaryApp();
  final auth = FirebaseAuth.instanceFor(app: app);

  if (Env.useEmulators) {
    await auth.useAuthEmulator(Env.emulatorHost, 9099);
  }

  try {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user!.uid;
  } finally {
    await auth.signOut();
  }
}

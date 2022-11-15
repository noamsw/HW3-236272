import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;


enum Status{
  Authenticating,
  Unauthenticated,
  Authenticated
}

class AuthNotifier extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _firestore = FirebaseFirestore.instance;
  Status _status = Status.Unauthenticated;
  bool _Authenticated = false;
  User? _user = null;
  String? _email;
  String? _profile;
  bool _hasProfile = false;


  AuthNotifier() {
    _auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser == null) {
        _user = null;
        _status = Status.Unauthenticated;
        _Authenticated = false;
      }
      else {
        _user = firebaseUser;
        _status = Status.Authenticated;
        _Authenticated = true;
      }
      notifyListeners();
    });
  }

  bool get hasProfile => _hasProfile;

  Status get status => _status;

  String? get email => _email;

  bool get authenticated => _Authenticated;

  String? get profile => _profile;

  Future<UserCredential?> signUp(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();

      var res = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password
      );
      await _firestore.collection('users').doc(email).set({
        'suggestions': [],
        'profile': false,
      });
      return res;
    }
    catch (e) {
      developer.log(e.toString(), name: 'Signup error');
      _status = Status.Unauthenticated;
      _Authenticated = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(
          email: email,
          password: password
      );
      _email = email;
      _Authenticated = true;
      developer.log("logged in", name: 'STATUS');
      var remoteData = await _firestore.collection('users').doc(_email).get();
      developer.log("logged in", name: 'STATUS');
      if(remoteData?.data()?["profile"]){
        _hasProfile = true;
        var cloudPath = "images";
        _profile = await _storage.ref(cloudPath).child("$_email.jpg").getDownloadURL();
      }
      developer.log("$_profile",name:"profile");
      return true;
    }
    catch (e) {
      // developer.log(e.toString(), name: 'SignIn error');
      _status = Status.Unauthenticated;
      _Authenticated = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signOut() async {
    try {
      _status = Status.Unauthenticated;
      notifyListeners();
      await _auth.signOut();
      _email = null;
      _Authenticated = false;
      return true;
    }
    catch (e) {
      // developer.log(e.toString(), name: 'SignIn error');
      _status = Status.Unauthenticated;
      _Authenticated = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> upload(String filename) async {
    var cloudPath = "images/$_email.jpg";
    var fileRef = _storage.ref(cloudPath); // cloudPath = “images/profile.jpg”
    var file = File(filename);
    try {
      await fileRef.putFile(file);
      var cloudPath = "images";
      _profile = await _storage.ref(cloudPath).child("$_email.jpg").getDownloadURL();
      developer.log("$_profile",name:"profile");
      notifyListeners();
    }
    catch (e) {
      developer.log(e.toString(), name: "FILE ERROR");
      return;
    }
  }

  Future<bool> addSuggestions(Set<String> suggestions) async {
    try {
      await _firestore.collection('users').doc(_email).update(
          {'suggestions': FieldValue.arrayUnion([...suggestions])});
      return true;
    } catch (e) {
      developer.log(e.toString(), name: 'adding val');
      return false;
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> getStoredSuggestions() async {
    try {
      return _firestore.collection('users').doc(_email).get();
    } catch (e) {
      developer.log(e.toString(), name: 'getting stored');
      return null;
    }
  }

  Future<bool> updateSuggestions(List suggestions) async {
    try {
      _firestore.collection('users').doc(_email).update(
          {'suggestions': suggestions});
      return true;
    } catch (e) {
      developer.log(e.toString(), name: 'adding val');
      return false;
    }
  }

}


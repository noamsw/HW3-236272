// Copyright 2018 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hello_me/providers/settings_notifier.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:snapping_sheet/snapping_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';


void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(App());
}


class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(
                  child: Text(snapshot.error.toString(),
                      textDirection: TextDirection.ltr)));
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return const MyApp();
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

// #docregion MyApp
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // #docregion build
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthNotifier(),
      child: MaterialApp(
        title: 'Startup Name Generator',
        theme: ThemeData(
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
        ),
        home: const RandomWords(),
      ),
    );
  }
// #enddocregion build
}
// #enddocregion MyApp


class RandomWords extends StatefulWidget {
  const RandomWords({Key? key}) : super(key: key);

  @override
  State<RandomWords> createState() => _RandomWordsState();
}

// #docregion RWS-var
class _RandomWordsState extends State<RandomWords> {
  final _suggestions = <WordPair>[];
  final _localsaved = <WordPair>{};
  final _remoteSaved = <String>{};
  final _biggerFont = const TextStyle(fontSize: 18);
  final _firestore = FirebaseFirestore.instance;
  final _snappingSheetController = SnappingSheetController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();



  Future<bool> _addSuggestion (Set<String> suggestions) async {
    return await context.read<AuthNotifier>().addSuggestions(suggestions);
  }


  Future<bool> _remSuggestion (String suggestion) async {
    try {
      DocumentSnapshot<Map<String, dynamic>>? remoteData = await context.read<AuthNotifier>().getStoredSuggestions();
      List userSaved = remoteData?.get('suggestions');
      userSaved.removeWhere((str){
        return str == suggestion;
      });
      if (!mounted) return false;
      await context.read<AuthNotifier>().updateSuggestions(userSaved);
      return true;
    } catch (e) {
      developer.log(e.toString(), name: 'removing val');
      return false;
    }
  }

  Future _sync () async{
    try {
      //first create a set of strings, so that we can use it to synce to the server
      //adding them to the currently empty remote set
      Set<String> localSuggestions = _localsaved.map((element){
        _remoteSaved.add(element.asPascalCase);
        return element.asPascalCase;
      }).toSet();
      var remoteData = await context.read<AuthNotifier>().getStoredSuggestions();
      var remoteSuggestions = remoteData?.data()?["suggestions"].toSet();
      developer.log("we got the data", name: "data fine");
      developer.log("${remoteSuggestions.toString()}", name: "remote data ");
      //add the remote elements as well
      remoteSuggestions.forEach((element) {
        _remoteSaved.add(element);
        // var words = element.toString().split("(?=\\p{Upper})");
        final beforeCapitalLetter = RegExp(r"(?=[A-Z])");
        var parts = element.toString().split(beforeCapitalLetter);
        if (parts.isNotEmpty && parts[0].isEmpty) parts = parts.sublist(1);
        developer.log("words: ${parts.toString()} , element in remote saved: ${element.toString()} , element split: ${(element.toString().split("(?=\\p{Upper})")).toString()}", name: "words split");
        var pair = WordPair(parts[0], parts[1]);
        if (_suggestions.contains(pair)){
          _localsaved.add(pair);
        }
        developer.log(_remoteSaved.toString(), name: 'Synced');
      });
      _addSuggestion(localSuggestions);
    } catch (e) {
      developer.log(e.toString(), name: 'Sync error');
      return;
    }
  }

  Future _validatePass () async{

    TextEditingController verifyPassController = TextEditingController();
    showModalBottomSheet(
        context: context, builder: (context){
      bool isLoading = context.watch<AuthNotifier>().status == Status.Authenticating;
      return Form(
        key: _formKey,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                  "Please Confirm Your Password"
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: TextFormField(
                controller: verifyPassController,
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Passwords must match';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  hintText: 'Confirm Password',
                ),
                obscureText: true,
              ),
            ),
            const Padding(padding: EdgeInsets.all(20)),
            SizedBox(
              width: 300.0,
              height: 40.0,
              child: TextButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(Colors.blue),
                  foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                ),
                onPressed: isLoading ? null : () async{
                  if (_formKey.currentState!.validate()) {
                    Future<UserCredential?> signUpRes = context.read<AuthNotifier>().signUp(_emailController.text, _passwordController.text);
                    UserCredential? signedUp = await signUpRes;
                    if (signedUp != null){
                      if (!mounted) return;
                      Navigator.of(context).pop(true);
                      _emailController.clear();
                      _passwordController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('You have signed up, you may now sign in')));
                    } else{
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('There was an error Signing up to the app')));
                    }
                  }
                },
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : const Text('Confirm'),
              ),
            ),
          ],
        ),
      );
    });
  }

  // Future _downloadProfile() async{
  //   var cloudPath = "images/profiles${context.read<AuthNotifier>().email.toString()}";
  //   var fileURL = await _storage.ref(cloudPath).child("name").getDownloadURL();//need to add name
  //   return Image.network(fileURL, height : 60.0, width: 60.0);
  // }


  Future _pickProfile() async{
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if(result == null){
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No image selected'),behavior: SnackBarBehavior.floating,));
    }
    PlatformFile fileResult = result!.files.single;
    String filename = fileResult.path.toString();
    if(!mounted) return;
    context.read<AuthNotifier>().upload(filename);
  }


  void _pushSaved() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          developer.log(_remoteSaved.toString(), name: 'remote');
          developer.log(_localsaved.toString(), name: 'local');
          Set<dynamic> saved = context.read<AuthNotifier>().authenticated?
          _remoteSaved
              : _localsaved.map((e) => e.asPascalCase).toSet();
          developer.log(saved.toString(), name: 'saved');
          final tiles = saved.map((pair) {
            return Dismissible(
              background: Container(
                color: Colors.deepPurple,
                child: Row(
                  children:  const [
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Delete Suggestion',
                        style :TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              key: UniqueKey(),
              child: ListTile(
                title: Text(pair.toString()),
              ),
              confirmDismiss: (DismissDirection direction) {
                return showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Delete suggestion'),
                        content: Text('are you sure you want to delete: ${pair.toString()} ?'),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Yes'),
                            onPressed: () {
                              if(context.read<AuthNotifier>().authenticated){
                                _remoteSaved.remove(pair.toString());
                                _remSuggestion(pair.toString());
                              }
                              final beforeCapitalLetter = RegExp(r"(?=[A-Z])");
                              var parts = pair.toString().split(beforeCapitalLetter);
                              if (parts.isNotEmpty && parts[0].isEmpty) parts = parts.sublist(1);
                              var wordpair = WordPair(parts[0].toLowerCase(), parts[1].toLowerCase());
                              setState(() {
                                _localsaved.remove(wordpair);
                              });
                              Navigator.of(context).pop(true);
                            },
                          ),TextButton(
                            child: const Text('No'),
                            onPressed: () {
                              Navigator.of(context).pop(false);
                            },
                          ),
                        ],
                      );
                    }
                );
              },
            );
          },
          );
          final divided = tiles.isNotEmpty
              ? ListTile.divideTiles(
            context: context,
            tiles: tiles,
          ).toList()
              : <Widget>[];
          return Scaffold(
            appBar: AppBar(
              title: const Text('Saved Suggestions'),
            ),
            body: ListView(children: divided),
          );
        },
      ),
    );
  }
  void _login() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          bool isLoading = context.watch<AuthNotifier>().status == Status.Authenticating;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Login'),
              foregroundColor: Colors.white,
            ),
            body: Column
              (
                children: [
                  const Padding(
                      padding: EdgeInsets.all(10.0)
                  ),
                  const Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Text(
                      'Welcome to Startup Names Generator, please log in!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(),
                        hintText: 'Email',
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(),
                        hintText: 'Password',
                      ),
                      obscureText: true,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(12),
                  ),
                  SizedBox(
                    width: 300.0,
                    height: 40.0,
                    child: TextButton(
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all<Color>(Colors.deepPurple),
                        foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                      ),
                      onPressed: isLoading ? null : () async{
                        bool signRes = await context.read<AuthNotifier>().signIn(_emailController.text, _passwordController.text);
                        _emailController.clear();
                        _passwordController.clear();
                        if (signRes){
                          await _sync();
                          setState(() {
                            Navigator.of(context).pop(); // pop of login page
                          });
                          developer.log("sync succesful",name:"sync end",);
                        } else{
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('There was an error logging into the app')));
                        }
                      },
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : const Text('login'),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(12),
                  ),
                  SizedBox(
                    width: 300.0,
                    height: 40.0,
                    child: TextButton(
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all<Color>(Colors.blue),
                        foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                      ),
                      onPressed: _validatePass,
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : const Text('New User? Click to Sign up'),
                    ),
                  ),
                ]
            ),
          );
        },
      ),
    );
  }
  void _logout() async {
    _remoteSaved.clear();
    await context.read<AuthNotifier>().signOut();
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully logged out'),));
  }
  // #enddocregion RWS-var
  Widget signedOutScaffold(){
    bool loggedIn = context.watch<AuthNotifier>().authenticated;
    developer.log("signed out",name:"STATUS");
    return Scaffold(
      appBar: AppBar(
        title: const Text('Startup Name Generator'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.star),
            onPressed: _pushSaved,
            tooltip: 'Saved Suggestions',
          ),
          IconButton(
            icon: loggedIn ? const Icon(Icons.exit_to_app) : const Icon(Icons.login),
            onPressed: loggedIn ? _logout : _login,
            tooltip: 'Login',
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemBuilder: /*1*/ (context, i) {
          if (i.isOdd) return const Divider(); /*2*/

          final index = i ~/ 2; /*3*/
          if (index >= _suggestions.length) {
            _suggestions.addAll(generateWordPairs().take(10)); /*4*/
          }
          final alreadySaved = _localsaved.contains(_suggestions[index]);
          // #docregion listTile
          return ListTile(
            title: Text(
              _suggestions[index].asPascalCase,
              style: _biggerFont,
            ),
            trailing: Icon(
              alreadySaved ? Icons.favorite : Icons.favorite_border,
              color: alreadySaved ? Colors.red : null,
              semanticLabel: alreadySaved ? 'Remove from saved' : 'Save',
            ),
            onTap: () {          // NEW from here ...
              setState(() {
                if (alreadySaved) {
                  if (context.read<AuthNotifier>().authenticated) {
                    developer.log("you were authorized", name: 'Auth');
                    _remoteSaved.remove(_suggestions[index].asPascalCase);
                    _remSuggestion(_suggestions[index].asPascalCase);
                  }
                  _localsaved.remove(_suggestions[index]);
                } else {
                  if (context.read<AuthNotifier>().authenticated) {
                    _remoteSaved.add(_suggestions[index].asPascalCase);
                    _addSuggestion({_suggestions[index].asPascalCase});
                  }
                  _localsaved.add(_suggestions[index]);
                }
              });                // to here.
            },
          );
          // #enddocregion listTile
        },
      ),
    );
  }
  // #docregion RWS-build


  Widget signedInScaffold(){
    bool hasProfile = false;
    bool loggedIn = context.watch<AuthNotifier>().authenticated;
    developer.log("logged in",name:"SCREEN");
    bool pressed = false;
    return SnappingSheet(
      // lockOverflowDrag: true,
      controller: _snappingSheetController,
      grabbingHeight: 75,
      grabbing: Scaffold(
        body: Material(
          child: InkWell(
            onTap:  (){
              if(pressed){
                pressed = !pressed;
                _snappingSheetController.snapToPosition(const SnappingPosition.factor(
                  positionFactor: 0.0,
                  snappingCurve: Curves.easeOutExpo,
                  snappingDuration: Duration(seconds: 1),
                  grabbingContentOffset: GrabbingContentOffset.top,
                )
                );
              } else{
                pressed = !pressed;
                _snappingSheetController.snapToPosition(const SnappingPosition.pixels(
                  positionPixels: 250,
                  snappingCurve: Curves.elasticOut,
                  snappingDuration: Duration(milliseconds: 1750),
                )
                );
              }
            },
            child: Container(
              color: Colors.grey,
              child: Center(
                child: Text("Welcome back, ${context.read<AuthNotifier>().email}",
                  style: const TextStyle(
                    color: Colors.black,
                    backgroundColor: Colors.grey,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),

        ),

      ),
      sheetBelow: SnappingSheetContent(
        draggable: true,
        child: Scaffold(
          body: Row(
            children: <Widget>[
              Flexible(
                child: Padding(
                  padding: EdgeInsets.all(10.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.blueGrey,
                    maxRadius: 50,
                    backgroundImage: context.read<AuthNotifier>().hasProfile ? NetworkImage(
                      (context.watch()<AuthNotifier>().profile.toString()),
                    ) : null,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(5),
                child: Column(
                  children: [
                    Flexible(
                      child: Align(
                        alignment: Alignment.center,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Text("${context.watch<AuthNotifier>().email}",
                            style: const TextStyle(
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Center(
                          child: TextButton(
                            onPressed: _pickProfile,
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all<Color>(Colors.deepPurple),
                              foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
                            ),
                            child: const Text("change avatar",
                              style: TextStyle(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      snappingPositions: const [
        SnappingPosition.factor(
          positionFactor: 0.0,
          snappingCurve: Curves.easeOutExpo,
          snappingDuration: Duration(seconds: 1),
          grabbingContentOffset: GrabbingContentOffset.top,
        ),
        SnappingPosition.pixels(
          positionPixels: 250,
          snappingCurve: Curves.elasticOut,
          snappingDuration: Duration(milliseconds: 1750),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Startup Name Generator'),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.star),
              onPressed: _pushSaved,
              tooltip: 'Saved Suggestions',
            ),
            IconButton(
              icon: loggedIn ? const Icon(Icons.exit_to_app) : const Icon(Icons.login),
              onPressed: loggedIn ? _logout : _login,
              tooltip: 'Login',
            ),
          ],
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemBuilder: /*1*/ (context, i) {
            if (i.isOdd) return const Divider(); /*2*/

            final index = i ~/ 2; /*3*/
            if (index >= _suggestions.length) {
              _suggestions.addAll(generateWordPairs().take(10)); /*4*/
            }
            final alreadySaved = _localsaved.contains(_suggestions[index]);
            // #docregion listTile
            return ListTile(
              title: Text(
                _suggestions[index].asPascalCase,
                style: _biggerFont,
              ),
              trailing: Icon(
                alreadySaved ? Icons.favorite : Icons.favorite_border,
                color: alreadySaved ? Colors.red : null,
                semanticLabel: alreadySaved ? 'Remove from saved' : 'Save',
              ),
              onTap: () {          // NEW from here ...
                setState(() {
                  if (alreadySaved) {
                    if (context.read<AuthNotifier>().authenticated) {
                      developer.log("you were authorized", name: 'Auth');
                      _remoteSaved.remove(_suggestions[index].asPascalCase);
                      _remSuggestion(_suggestions[index].asPascalCase);
                    }
                    _localsaved.remove(_suggestions[index]);
                  } else {
                    if (context.read<AuthNotifier>().authenticated) {
                      _remoteSaved.add(_suggestions[index].asPascalCase);
                      _addSuggestion({_suggestions[index].asPascalCase});
                    }
                    _localsaved.add(_suggestions[index]);
                  }
                });                // to here.
              },
            );
            // #enddocregion listTile
          },
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    bool loggedIn = context.read<AuthNotifier>().authenticated;
    return context.read<AuthNotifier>().authenticated ? signedInScaffold() : signedOutScaffold();
    // #docregion itemBuilder
    // return Scaffold(
    //     appBar: AppBar(
    //       title: const Text('Startup Name Generator'),
    //       actions: <Widget>[
    //         IconButton(
    //         icon: const Icon(Icons.star),
    //         onPressed: _pushSaved,
    //         tooltip: 'Saved Suggestions',
    //         ),
    //         IconButton(
    //           icon: loggedIn ? const Icon(Icons.exit_to_app) : const Icon(Icons.login),
    //           onPressed: loggedIn ? _logout : _login,
    //           tooltip: 'Login',
    //         ),
    //       ],
    //     ),
    //   body: ListView.builder(
    //     padding: const EdgeInsets.all(16.0),
    //     itemBuilder: /*1*/ (context, i) {
    //       if (i.isOdd) return const Divider(); /*2*/
    //
    //       final index = i ~/ 2; /*3*/
    //       if (index >= _suggestions.length) {
    //         _suggestions.addAll(generateWordPairs().take(10)); /*4*/
    //       }
    //       final alreadySaved = _localsaved.contains(_suggestions[index]);
    //       // #docregion listTile
    //       return ListTile(
    //         title: Text(
    //           _suggestions[index].asPascalCase,
    //           style: _biggerFont,
    //         ),
    //         trailing: Icon(
    //           alreadySaved ? Icons.favorite : Icons.favorite_border,
    //           color: alreadySaved ? Colors.red : null,
    //           semanticLabel: alreadySaved ? 'Remove from saved' : 'Save',
    //         ),
    //         onTap: () {          // NEW from here ...
    //           setState(() {
    //             if (alreadySaved) {
    //               if (context.read<AuthNotifier>().authenticated) {
    //                 developer.log("you were authorized", name: 'Auth');
    //                 _remoteSaved.remove(_suggestions[index].asPascalCase);
    //                 _remSuggestion(_suggestions[index].asPascalCase);
    //               }
    //               _localsaved.remove(_suggestions[index]);
    //             } else {
    //               if (context.read<AuthNotifier>().authenticated) {
    //                 _remoteSaved.add(_suggestions[index].asPascalCase);
    //                 _addSuggestion({_suggestions[index].asPascalCase});
    //               }
    //               _localsaved.add(_suggestions[index]);
    //             }
    //           });                // to here.
    //         },
    //       );
    //       // #enddocregion listTile
    //     },
    //   ),
    // );
    // #enddocregion itemBuilder
  }
// #enddocregion RWS-build
// #docregion RWS-var
}
// #enddocregion RWS-var

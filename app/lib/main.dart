import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:percent_indicator/percent_indicator.dart';

void main() => runApp(App());

final GlobalKey<NavigatorState> navigatorKey = new GlobalKey<NavigatorState>();

class App extends StatefulWidget {
    @override
    _AppState createState() => _AppState();
}

class _AppState extends State<App> {
    @override
    void initState() {
        super.initState();

        FirebaseAuth.instance.onAuthStateChanged.listen((FirebaseUser user) {
            if (user == null) {
                navigatorKey.currentState.pushReplacement(
                    MaterialPageRoute(
                        builder: (context) => LoginPage(),
                    ),
                );
            }
        });
    }

    @override
    Widget build(BuildContext context) {
      return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'BizBoard',
          theme: ThemeData(
              primaryColor: Colors.blue[700],
              primaryColorDark: Colors.purple[800],
              accentColor: Colors.orange[800],
          ),
          home: FutureBuilder<FirebaseUser>(
              future: FirebaseAuth.instance.currentUser(),
              builder: (BuildContext context, AsyncSnapshot<FirebaseUser> snapshot) {
                  switch(snapshot.connectionState) {
                      case ConnectionState.none:
                      case ConnectionState.waiting:
                          return Scaffold(
                              body: Center(
                                  child: CircularProgressIndicator()
                              ),
                          );
                      case ConnectionState.active:
                      case ConnectionState.done:
                          if (snapshot.hasData) {
                              return StatsPage();
                          } else {
                              return LoginPage();
                          }
                  }
              }
          ),
    );
    }
}

class LoginPage extends StatefulWidget {
    @override
    _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
    final _formKey = GlobalKey<FormState>();
    String emailAddress;

    @override
    Widget build(BuildContext context) {
        return Scaffold(
          appBar: AppBar(
            title: Text('BizBoard'),
          ),
          drawer: AppDrawer(),
          body: Center(
            child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                    Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                            Text('Welcome!', style: Theme.of(context).textTheme.title),
                            SizedBox(height: 50.0),
                            Form(
                                key: _formKey,
                                child: Column(
                                    children: <Widget>[
                                        TextFormField(
                                            decoration: const InputDecoration(
                                                icon: Icon(Icons.email),
                                                labelText: 'Login Email',
                                            ),
                                            keyboardType: TextInputType.emailAddress,
                                            autofocus: true,
                                            onSaved: (String value) => emailAddress = value,
                                            validator: (String value) {
                                                if (value == 'a' || value == 't') { return null; }
 
                                                return EmailValidator.validate(value) ? null : 'Invalid email address';
                                            }
                                        ),
                                        SizedBox(height: 50.0),
                                        Builder(
                                            builder: (BuildContext context) {
                                                return RaisedButton(
                                                    onPressed: () async {
                                                        _formKey.currentState.save();
                                                        if (_formKey.currentState.validate()) {
                                                            Scaffold.of(context).showSnackBar(
                                                                SnackBar(content: Text('Sending passcode...')),
                                                            );

                                                            try {
                                                                await CloudFunctions.instance.getHttpsCallable(
                                                                    functionName: 'sendPasscode'
                                                                ).call(<String, dynamic>{
                                                                    'email': emailAddress
                                                                });
                                                            } catch (e) {
                                                                showDialog(
                                                                    context: context,
                                                                    builder: (BuildContext context) {
                                                                        return AlertDialog(
                                                                            title: Text(e.details['message']),
                                                                            actions: <Widget>[
                                                                                FlatButton(
                                                                                    child: Text('OK'),
                                                                                    onPressed: () { Navigator.of(context).pop(); }
                                                                                ),
                                                                            ],
                                                                        );
                                                                    }
                                                                );
                                                                return;
                                                            } finally {
                                                                Scaffold.of(context).hideCurrentSnackBar();
                                                            }

                                                            Navigator.of(context).pushReplacement(
                                                                MaterialPageRoute(
                                                                    builder: (context) => AuthenticationPage(emailAddress: emailAddress),
                                                                ),
                                                            );
                                                        }
                                                    },
                                                    child: Text('REQUEST PASSCODE'),
                                                );
                                            }
                                        ),
                                    ],
                                ),
                            ),
                        ],
                    ),
                ],
            ),
          )
        );
    }
}

class AppDrawer extends StatelessWidget {
    AppDrawer({Key key}) : super(key: key);

    @override
    Widget build(BuildContext context) {
        return Drawer(
            child: SafeArea(
                child: ListView(
                    children: <Widget>[
                        AboutListTile(
                            icon: Icon(Icons.info),
                            applicationIcon: FlutterLogo(),
                            applicationName: 'BizBoard',
                            applicationVersion: 'March 2020',
                            aboutBoxChildren: <Widget>[
                                Text(
                                    "BizBoard provides quick pulse and tracking functionality for a specific business unit.\n\n"
                                    "It will help to track:\n• Target, boosting, and sales\n• Pursuits and Proposals\n• Staffing plan\n"
                                    "• Enablement and preparation tracking"
                                ),
                            ],
                        ),
                        ListTile(
                            leading: Icon(Icons.exit_to_app),
                            title: Text('Sign out'),
                            onTap: () {
                                FirebaseAuth.instance.signOut();
                            }
                        ),
                    ],
                )
            ),
        );
    }
}

class StatsPage extends StatefulWidget {
    StatsPage({Key key}) : super(key: key);

    @override
    _StatsPageState createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
    @override
    Widget build(BuildContext context) {
        return Scaffold(
            appBar: AppBar(
                title: Text('BizBoard')
            ),
            drawer: AppDrawer(),
            body: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 4,
                mainAxisSpacing: 3,
                childAspectRatio: 0.75,
                children: <Widget>[
                    Card(
                        child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                    Text.rich(
                                        TextSpan(
                                            text: 'Bookings',
                                            style: Theme.of(context).textTheme.title.apply(color: Theme.of(context).primaryColorDark),
                                            children: <TextSpan>[
                                                TextSpan(text: ' (yearly)', style: Theme.of(context).textTheme.body1)
                                            ],
                                        ),
                                    ),
                                    Text('Achieved 10%', style: Theme.of(context).textTheme.caption),
                                    Spacer(),
                                    Center(
                                        child: CircularPercentIndicator(
                                            radius: 110.0,
                                            lineWidth: 5.0,
                                            percent: 0.1,
                                            center: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: <Widget>[
                                                    Text('20', style: Theme.of(context).textTheme.display3
                                                            .apply(color: Theme.of(context).primaryColorDark)),
                                                    Text('Actual', style: Theme.of(context).textTheme.caption),
                                                ]
                                            ),
                                            progressColor: Theme.of(context).accentColor,
                                        ),
                                    ),
                                    Spacer(),
                                    Row(
                                        children: <Widget>[
                                            Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: <Widget>[
                                                    Text('YEL', style: Theme.of(context).textTheme.caption),
                                                    Text('320', style: Theme.of(context).textTheme.subhead
                                                            .apply(color: Theme.of(context).primaryColorDark))
                                                ],
                                            ),
                                            Spacer(),
                                            Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: <Widget>[
                                                    Text('Target', style: Theme.of(context).textTheme.caption),
                                                    Text('300', style: Theme.of(context).textTheme.subhead
                                                            .apply(color: Theme.of(context).primaryColorDark)),
                                                ],
                                            ),
                                        ],
                                    ),
                                ],
                            ),
                        ),
                    ),
                    Card(
                        child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                    Text('Proposals', style: Theme.of(context).textTheme.title
                                            .apply(color: Theme.of(context).primaryColorDark)),
                                    Text('Win 10%', style: Theme.of(context).textTheme.caption),
                                    Spacer(),
                                    Center(
                                        child: CircularPercentIndicator(
                                            radius: 110.0,
                                            lineWidth: 5.0,
                                            percent: 0.1,
                                            center: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: <Widget>[
                                                    Text('10', style: Theme.of(context).textTheme.display3
                                                            .apply(color: Theme.of(context).primaryColorDark)),
                                                    Text('In Progress', style: Theme.of(context).textTheme.caption)
                                                ]
                                            ),
                                            progressColor: Theme.of(context).accentColor,
                                        ),
                                    ),
                                    Spacer(),
                                    Row(
                                        children: <Widget>[
                                            Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: <Widget>[
                                                    Text('Completed', style: Theme.of(context).textTheme.caption),
                                                    Text('20', style: Theme.of(context).textTheme.subhead
                                                            .apply(color: Theme.of(context).primaryColorDark))
                                                ],
                                            ),
                                            Spacer(),
                                            Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: <Widget>[
                                                    Text('Total', style: Theme.of(context).textTheme.caption),
                                                    Text('30', style: Theme.of(context).textTheme.subhead
                                                            .apply(color: Theme.of(context).primaryColorDark))
                                                ],
                                            ),
                                        ],
                                    ),
                                ],
                            ),
                        ),
                    ),
                    Card(
                        child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                    Text('Staffing', style: Theme.of(context).textTheme.title
                                            .apply(color: Theme.of(context).primaryColorDark)),
                                    SizedBox(height: 15.0),
                                    Row(
                                        children: <Widget>[
                                            Column(
                                                children: <Widget>[
                                                    Text('20', style: Theme.of(context).textTheme.display3
                                                            .apply(color: Theme.of(context).primaryColorDark)),
                                                    Text('Demand', style: Theme.of(context).textTheme.caption),
                                                ],
                                            ),
                                            Spacer(),
                                            Column(
                                                children: <Widget>[
                                                    Text('10', style: Theme.of(context).textTheme.display3
                                                            .apply(color: Theme.of(context).primaryColorDark)),
                                                    Text('Bench', style: Theme.of(context).textTheme.caption),
                                                ],
                                            ),
                                        ],
                                    ),
                                    Spacer(),
                                    Row(
                                        children: <Widget>[
                                            Column(
                                                children: <Widget>[
                                                    Text('12', style: Theme.of(context).textTheme.display3
                                                            .apply(color: Theme.of(context).primaryColorDark)),
                                                    Text('Offers', style: Theme.of(context).textTheme.caption),
                                                ],
                                            ),
                                            Spacer(),
                                            Column(
                                                children: <Widget>[
                                                    Text('10', style: Theme.of(context).textTheme.display3
                                                            .apply(color: Theme.of(context).primaryColorDark)),
                                                    Text('Resignations', style: Theme.of(context).textTheme.caption),
                                                ],
                                            ),
                                        ],
                                    ),
                                ]
                            ),
                        ),
                    ),
                    Card(
                        child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                    Text('Enablement', style: Theme.of(context).textTheme.title
                                            .apply(color: Theme.of(context).primaryColorDark)),
                                    SizedBox(height: 15.0),
                                    Center(
                                        child: Text('People', style: Theme.of(context).textTheme.caption
                                                .apply(fontWeightDelta: 2)),
                                    ),
                                    Row(
                                        children: <Widget>[
                                            Column(
                                                children: <Widget>[
                                                    Text('30', style: Theme.of(context).textTheme.display3
                                                            .apply(color: Theme.of(context).primaryColorDark)),
                                                    Text('Trained', style: Theme.of(context).textTheme.caption),
                                                ],
                                            ),
                                            Spacer(),
                                            Column(
                                                children: <Widget>[
                                                    Text('10', style: Theme.of(context).textTheme.display3
                                                            .apply(color: Theme.of(context).primaryColorDark)),
                                                    Text('Certified', style: Theme.of(context).textTheme.caption),
                                                ],
                                            ),
                                        ],
                                    ),
                                    Spacer(),
                                    Center(
                                        child: Text('Trainings', style: Theme.of(context).textTheme.caption
                                                .apply(fontWeightDelta: 2)),
                                    ),
                                    Row(
                                        children: <Widget>[
                                            Column(
                                                children: <Widget>[
                                                    Text('30', style: Theme.of(context).textTheme.display3
                                                            .apply(color: Theme.of(context).primaryColorDark)),
                                                    Text('Planned', style: Theme.of(context).textTheme.caption),
                                                ],
                                            ),
                                            Spacer(),
                                            Column(
                                                children: <Widget>[
                                                    Text('10', style: Theme.of(context).textTheme.display3
                                                            .apply(color: Theme.of(context).primaryColorDark)),
                                                    Text('Completed', style: Theme.of(context).textTheme.caption),
                                                ],
                                            ),
                                        ],
                                    ),
                                ]
                            ),
                        ),
                    ),
                ],
            ),
        );
    }
}

class AuthenticationPage extends StatefulWidget {
    final String emailAddress;

    AuthenticationPage({Key key, @required this.emailAddress}) : super(key: key);

    @override
    _AuthenticationPageState createState() => _AuthenticationPageState();
}

class _AuthenticationPageState extends State<AuthenticationPage> {
    final _formKey = GlobalKey<FormState>();
    String passcode;
    String token;

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            appBar: AppBar(
                title: Text('BizBoard'),
            ),
            body: Center(
                child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                        Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                                Text('Please enter the passcode sent to:', style: Theme.of(context).textTheme.title),
                                Text(widget.emailAddress, style: Theme.of(context).textTheme.subhead),
                                SizedBox(height: 50.0),
                                Form(
                                    key: _formKey,
                                    child: Column(
                                        children: <Widget>[
                                            TextFormField(
                                                decoration: const InputDecoration(
                                                    icon: Icon(Icons.vpn_key),
                                                    labelText: 'Passcode',
                                                ),
                                                autofocus: true,
                                                onSaved: (String value) => passcode = value,
                                            ),
                                            SizedBox(height: 50.0),
                                            Builder(
                                                builder: (BuildContext context) {
                                                    return RaisedButton(
                                                        onPressed: () async {
                                                            _formKey.currentState.save();

                                                            Scaffold.of(context).showSnackBar(
                                                                SnackBar(content: Text('Validating passcode...')),
                                                            );

                                                            try {
                                                                dynamic response = (await CloudFunctions.instance.getHttpsCallable(
                                                                    functionName: 'verifyPasscode'
                                                                ).call(<String, dynamic>{
                                                                    'email': widget.emailAddress,
                                                                    'passcode': passcode
                                                                })).data;

                                                                if (response['token'] != null) {
                                                                    await FirebaseAuth.instance.signInWithCustomToken(
                                                                        token: response['token'],
                                                                    );
                                                                } else {
                                                                    throw new Exception("Invalid or expired passscode");
                                                                }
                                                            } on CloudFunctionsException catch (e) {
                                                                showDialog(
                                                                    context: context,
                                                                    builder: (BuildContext context) {
                                                                        return AlertDialog(
                                                                            title: Text(e.details['message']),
                                                                            actions: <Widget>[
                                                                                FlatButton(
                                                                                    child: Text('OK'),
                                                                                    onPressed: () { Navigator.of(context).pop(); }
                                                                                ),
                                                                            ],
                                                                        );
                                                                    }
                                                                );
                                                                return;
                                                            } catch (e) {
                                                                showDialog(
                                                                    context: context,
                                                                    builder: (BuildContext context) {
                                                                        return AlertDialog(
                                                                            title: Text(e.message),
                                                                            actions: <Widget>[
                                                                                FlatButton(
                                                                                    child: Text('OK'),
                                                                                    onPressed: () { Navigator.of(context).pop(); }
                                                                                ),
                                                                            ],
                                                                        );
                                                                    }
                                                                );
                                                                return;
                                                            } finally {
                                                                Scaffold.of(context).hideCurrentSnackBar();
                                                            }

                                                            Navigator.of(context).pushReplacement(
                                                                MaterialPageRoute(
                                                                    builder: (context) => StatsPage(),
                                                                ),
                                                            );
                                                        },
                                                        child: Text('SUBMIT'),
                                                    );
                                                }
                                            ),
                                        ],
                                    ),
                                ),
                            ],
                        )
                    ],
                ),
            ),
        );
    }
}

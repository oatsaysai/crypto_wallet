import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';

void main() => runApp(MaterialApp(
      theme: new ThemeData(
        primaryColor: Colors.pinkAccent,
      ),
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    ));

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => new _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var list;
  var random;

  var refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    refreshList();
  }

  Future<Null> refreshList() async {
    refreshKey.currentState?.show(atTop: true);
    await Future.delayed(Duration(seconds: 1));
    setState(() {});
    return null;
  }

  @override
  Widget build(BuildContext context) {
    var futureBuilder = new FutureBuilder(
      future: getBinanceData(),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        print(snapshot.connectionState);
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
            return showProgressIndicator();
          default:
            if (snapshot.hasError)
              return new Text('Error: ${snapshot.error}');
            else
              return createListView(context, snapshot);
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text("Wallet"),
      ),
      body: RefreshIndicator(
        key: refreshKey,
        child: futureBuilder,
        onRefresh: refreshList,
      ),
    );
  }
}

Future<String> getBinanceData() async {
  var cryptoList = await getList();

  var param =
      'timestamp=' + (new DateTime.now().millisecondsSinceEpoch).toString();

  String stringKey =
      'nGi8NLC8AICvW4uz3CAT4ZBVRC83B5F2CJwlAQXzCNrloz2ej8nHsIDfyunY7jKy';
  String message = param;

  List<int> messageBytes = utf8.encode(message);
  List<int> key = utf8.encode(stringKey);

  Hmac hmac = new Hmac(sha256, key);
  Digest digest = hmac.convert(messageBytes);
  print('$digest');
  param += '&signature=$digest';
  print(param);

  final response = await http
      .get('https://api.binance.com/api/v3/account?' + param, headers: {
    'X-MBX-APIKEY':
        'HS9gJ3bMqGYAdQovmmEwJckldkMhkRreC6lQ0KJah6Ja8i6g3TH1pBOUnGGAgU33'
  });

  final responseJson = json.decode(response.body);
  double sum = 0.0;

  print('Binance');
  print(responseJson);
  print(responseJson['balances']);

  List<Map> list = new List<Map>();
  for (var value in responseJson['balances']) {
    if (double.parse(value['free']) > 0.0) {
      var id = cryptoList[value['asset']].toString();
      final priceRes = await http.get(
          'https://api.coinmarketcap.com/v2/ticker/' + id + '/?convert=THB');
      final priceResJson = json.decode(priceRes.body);
      var mapData = new Map();
      mapData["id"] = id;
      mapData["symbol"] = value['asset'];
      mapData["price"] = priceResJson['data']['quotes']['THB']['price'];
      mapData["quantity"] = value['free'];
      mapData["value"] = mapData["price"] * double.parse(mapData["quantity"]);
      sum += mapData["value"];
      mapData["percent_change_24h"] =
          priceResJson['data']['quotes']['USD']['percent_change_24h'];
      list.add(mapData);
    }
  }

  // Get BX data
  // http.For data = new FormData();

  var nonce = (new DateTime.now().millisecondsSinceEpoch).toString();
  var bytes = utf8.encode('daff6e28c043' + nonce + '949ddf0093a3');
  var signature = sha256.convert(bytes).toString();
  var responseBX = await http.post('https://bx.in.th/api/balance/',
      body: {'key': 'daff6e28c043', 'nonce': nonce, 'signature': signature},
      encoding: Encoding.getByName('utf-8'));

  final responseJsonBX = json.decode(responseBX.body);
  print('Get BX data');
  print(responseJsonBX);

  for (var key in responseJsonBX['balance'].keys) {
    // print(cryptoList[key.toString()].toString());
    var value = responseJsonBX['balance'][key];
    if ((double.parse(value['total'].toString()) > 0.0) && cryptoList[key.toString()] != null) {
      var id = cryptoList[key.toString()].toString();
      final priceRes = await http.get(
          'https://api.coinmarketcap.com/v2/ticker/' + id + '/?convert=THB');
      final priceResJson = await json.decode(priceRes.body);
      print(priceResJson);
      var mapData = new Map();
      mapData["id"] = id;
      mapData["symbol"] = key.toString();
      mapData["price"] = priceResJson['data']['quotes']['THB']['price'];
      mapData["quantity"] = value['total'].toString();
      // mapData["quantity"] = (double.parse(mapData["quantity"])*13.0).toString();
      mapData["value"] = mapData["price"] * double.parse(mapData["quantity"]);
      sum += mapData["value"];
      mapData["percent_change_24h"] =
          priceResJson['data']['quotes']['USD']['percent_change_24h'];

      print(mapData);
      list.add(mapData);
    } else {
      // var mapData = new Map();
      // mapData["id"] = "0";
      // mapData["symbol"] = key.toString();
      // mapData["price"] = 1.0;
      // mapData["quantity"] = value['total'].toString();
      // mapData["value"] = mapData["price"] * double.parse(mapData["quantity"]);
      // sum += mapData["value"];
      // // mapData["percent_change_24h"] =
      // //     priceResJson['data']['quotes']['USD']['percent_change_24h'];

      // print(mapData);
      // list.add(mapData);
    }
  }

  var result = new Map();
  result['total'] = sum;
  result['data'] = list;

  String jsonData = JSON.encode(result);
  print(jsonData);
  return jsonData;
}

Widget showProgressIndicator() {
  return new Center(
    child: Platform.isAndroid
        ? new CircularProgressIndicator()
        : new CupertinoActivityIndicator(),
  );
}

List<Crypto> getCryptoList(json) {
  List<Crypto> cryptos = new List<Crypto>();
  json.forEach((value) {
    var crypto = new Crypto.fromJson(value);
    cryptos.add(crypto);
  });
  cryptos..sort((a, b) => b.value.compareTo(a.value));
  return cryptos;
}

Widget createListView(BuildContext context, AsyncSnapshot snapshot) {
  final responseJson = json.decode(snapshot.data);
  print(responseJson['data']);

  final cryptolist = getCryptoList(responseJson['data']);
  print(cryptolist);

  final oCcy = new NumberFormat("#,##0.00", "en_US");
  final oCcy2 = new NumberFormat("#,##0", "en_US");
  final crypFormat = new NumberFormat("0.0000000", "en_US");

  Row buildButtonColumn1(String id, String label1, String label2) {
    Color color = Theme.of(context).primaryColor;

    return new Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        new Padding(
          padding: new EdgeInsets.only(
            top: 3.0,
            right: 10.0,
          ),
          child: new Image(
            image: new NetworkImage(
                'https://s2.coinmarketcap.com/static/img/coins/32x32/' +
                    id +
                    '.png',
                scale: 1.0),
          ),
        ),
        new Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.end,
          // crossAxisAlignment: CrossAxisAlignment.start,
          // mainAxisSize: MainAxisSize.min,
          // mainAxisAlignment: MainAxisAlignment.start,
          children: [
            new Container(
              margin: const EdgeInsets.only(top: 0.0),
              child: new Text(
                label1,
                style: new TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Roboto',
                  fontSize: 16.0,
                ),
              ),
            ),
            new Container(
              margin: const EdgeInsets.only(top: 4.0),
              child: new Text(
                label2,
                style: new TextStyle(
                  color: Colors.grey[500],
                ),
              ),
            ),
          ],
        )
      ],
    );
  }

  Row buildButtonColumn2(String label1, String label2) {
    Color color = Theme.of(context).primaryColor;

    label1 = label1.padLeft(10, ' ');
    // label2 = label2.padLeft(10, '0');

    if (label2.contains('-')) {
      return new Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          new Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              new Container(
                margin: const EdgeInsets.only(top: 0.0),
                child: new Text(
                  label1,
                  style: new TextStyle(
                    color: Colors.grey[500],
                  ),
                ),
              ),
              new Container(
                margin: const EdgeInsets.only(top: 4.0),
                child: new Text(
                  label2,
                  style: new TextStyle(color: Colors.red),
                ),
              ),
            ],
          )
        ],
      );
    } else {
      return new Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          new Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              new Container(
                margin: const EdgeInsets.only(top: 0.0),
                child: new Text(
                  label1,
                  style: new TextStyle(
                    color: Colors.grey[500],
                  ),
                ),
              ),
              new Container(
                margin: const EdgeInsets.only(top: 4.0),
                child: new Text(
                  label2,
                  style: new TextStyle(color: Colors.green),
                ),
              ),
            ],
          )
        ],
      );
    }
  }

  Row buildButtonColumn3(String label1, String label2) {
    Color color = Theme.of(context).primaryColor;

    label1 = label1.padLeft(10, ' ');
    label2 = label2.padLeft(15, ' ');

    return new Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        new Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            new Container(
              margin: const EdgeInsets.only(top: 0.0),
              child: new Text(
                label1,
                style: new TextStyle(
                  color: Colors.grey[500],
                ),
              ),
            ),
            new Container(
              margin: const EdgeInsets.only(top: 4.0),
              child: new Text(
                label2,
                style: new TextStyle(
                  color: Colors.grey[500],
                ),
              ),
            ),
          ],
        )
      ],
    );
  }

  return new ListView.builder(
    itemCount: cryptolist.length + 1,
    itemBuilder: (BuildContext context, int index) {
      if (index == 0) {
        return new Card(
          child: new Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              new Container(
                padding: new EdgeInsets.only(top: 16.0),
                child: new Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    new Text(oCcy.format(responseJson['total']),
                        style: new TextStyle(
                          fontSize: 35.0,
                          color: Colors.pinkAccent,
                        ))
                  ],
                ),
              ),
              new Container(
                padding: new EdgeInsets.only(top: 5.0, bottom: 5.0),
                child: new Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    new Text('THB',
                        style: new TextStyle(
                          fontSize: 20.0,
                          color: Colors.black,
                        ))
                  ],
                ),
              ),
            ],
          ),
        );
      } else {
        return new Container(
          decoration: new BoxDecoration(
            border: new Border(
                bottom: new BorderSide(
              color: Colors.grey,
              width: 0.3,
            )),
          ),
          padding: const EdgeInsets.all(10.0),
          child: new Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              buildButtonColumn1(
                  cryptolist[index - 1].id,
                  cryptolist[index - 1].symbol,
                  crypFormat.format(cryptolist[index - 1].quantity)),
              buildButtonColumn2(oCcy2.format(cryptolist[index - 1].price),
                  oCcy.format(cryptolist[index - 1].percent_change_24h) + ' %'),
              buildButtonColumn3(
                  oCcy.format(cryptolist[index - 1].value), 'THB'),
            ],
          ),
        );
      }
    },
  );
}

class Crypto {
  final String id;
  final String symbol;
  final double price;
  final double quantity;
  final double value;
  final double percent_change_24h;

  Crypto(
      {this.id,
      this.symbol,
      this.price,
      this.quantity,
      this.value,
      this.percent_change_24h});

  factory Crypto.fromJson(Map<String, dynamic> json) {
    var quantity = double.parse(json['quantity']);
    return new Crypto(
      id: json['id'],
      symbol: json['symbol'],
      price: json['price'],
      quantity: quantity,
      value: json['value'],
      percent_change_24h: json['percent_change_24h'],
    );
  }
}

Future<Map> getList() async {
  print('getList');
  final response = await http.get('https://api.coinmarketcap.com/v2/listings/');
  final responseJson = json.decode(response.body);
  var cryptoList = new Map();
  responseJson['data'].forEach((value) {
    cryptoList[value['symbol']] = value['id'];
  });
  print(cryptoList);
  return cryptoList;
}

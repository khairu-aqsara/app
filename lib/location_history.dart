import 'dart:async';
import 'package:covidtrace/helper/location.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'storage/location.dart';
import 'storage/user.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';

final Map<String, Icon> activities = {
  'unknown': Icon(Icons.not_listed_location),
  'still': Icon(Icons.location_on),
  'on_foot': Icon(Icons.directions_walk),
  'walking': Icon(Icons.directions_walk),
  'running': Icon(Icons.directions_run),
  'on_bicycle': Icon(Icons.directions_bike),
  'in_vehicle': Icon(Icons.directions_car),
};

class LocationHistory extends StatefulWidget {
  @override
  LocationHistoryState createState() => LocationHistoryState();
}

class LocationHistoryState extends State {
  String _filter = 'all';
  Map<String, Map<int, List<LocationModel>>> _locationsIndex = Map();
  List<LocationModel> _locations = [];
  List<LocationModel> _display = [];
  LocationModel _selected;
  LatLng _currentLocation;
  bool _nearHome;
  Completer<GoogleMapController> _controller = Completer();
  List<Marker> _markers = [];
  UserModel _user;

  @override
  void initState() {
    super.initState();
    loadInitState();
  }

  Future<void> loadInitState() async {
    await loadLocations();
    await loadUser();
    var position = await currentLocation();
    var nearHome = await UserModel.isInHome(position);
    setState(() => _nearHome = nearHome);
  }

  loadUser() async {
    var user = await UserModel.find();
    setState(() => _user = user);
  }

  Future<LatLng> currentLocation() async {
    var loc = await locateCurrentPosition();
    setState(() => _currentLocation = loc);

    return loc;
  }

  Future<void> loadLocations() async {
    var locations = await LocationModel.findAll(
        where: 'sample = 0', orderBy: 'timestamp DESC');

    setState(() {
      _locations = locations;
    });
    setFilter(_filter);
  }

  Future<void> removeLocation(LocationModel item) async {
    await item.destroy();
    await loadLocations();
  }

  setFilter(String value) {
    var locations = value == 'exposed'
        ? _locations.where((l) => l.exposure).toList()
        : _locations;

    // bucket locations by day and hour
    Map<String, Map<int, List<LocationModel>>> locationsIndex = Map();
    locations.forEach((l) {
      var timestamp = l.timestamp.toLocal();
      var dayHour = DateFormat.EEEE().add_MMMd().format(timestamp);
      locationsIndex[dayHour] ??= Map<int, List<LocationModel>>();
      locationsIndex[dayHour][timestamp.hour] ??= List<LocationModel>();
      locationsIndex[dayHour][timestamp.hour].add(l);
    });

    setState(() {
      _locationsIndex = locationsIndex;
      _filter = value;
      _display = locations;
    });

    setLocation(_display.length > 0 ? _display.first : null);
  }

  setLocation(LocationModel item) async {
    if (item == null) {
      setState(() {
        _selected = null;
        _markers = [];
      });

      return;
    }

    var loc = LatLng(item.latitude, item.longitude);
    setState(() {
      _selected = item;
      _markers = [
        Marker(
            markerId: MarkerId(item.id.toString()),
            position: loc,
            onTap: () => launchMapsApp(loc))
      ];
    });

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLng(loc));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Location History'),
        ),
        body: Column(children: [
          _nearHome != null
              ? Container(
                  color: Colors.blueGrey,
                  child: ListTileTheme(
                    textColor: Colors.white,
                    iconColor: Colors.white,
                    child: ListTile(
                      trailing: Icon(
                        _nearHome ? Icons.location_off : Icons.location_on,
                        size: 35,
                      ),
                      title: Text(_nearHome
                          ? 'Near your home'
                          : 'Location tracking on'),
                      subtitle: Text(_nearHome
                          ? 'Location tracking is off.'
                          : 'The location history is only on your phone.'),
                    ),
                  ))
              : Container(),
          Flexible(
              flex: 2,
              child: Stack(children: [
                if (_selected != null || _currentLocation != null)
                  GoogleMap(
                    mapType: MapType.normal,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    initialCameraPosition: CameraPosition(
                        target: _selected != null
                            ? _selected.latLng
                            : _currentLocation,
                        zoom: 16),
                    markers: _markers.toSet(),
                    circles: _user?.home != null
                        ? [
                            new Circle(
                                circleId: CircleId('home'),
                                center: _user.home,
                                radius: _user.homeRadius,
                                fillColor: Colors.blueGrey.withOpacity(.2),
                                strokeColor: Colors.blueGrey,
                                strokeWidth: 2)
                          ].toSet()
                        : Set(),
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                    },
                  ),
                Positioned(
                    left: 0,
                    right: 0,
                    bottom: 15.0,
                    child: Center(
                        child: CupertinoSlidingSegmentedControl(
                            backgroundColor: Color(0xCCCCCCCC),
                            padding: EdgeInsets.all(5),
                            groupValue: _filter,
                            children: {
                              'all': Text('All Locations'),
                              'exposed': Text('Potential Exposures'),
                            },
                            onValueChanged: setFilter))),
              ])),
          Divider(
            height: 0,
            color: Colors.grey,
          ),
          Flexible(
              flex: 3,
              child: RefreshIndicator(
                  onRefresh: loadLocations,
                  child: CustomScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      slivers: _locationsIndex.entries
                          .map((MapEntry<String, Map<int, List<LocationModel>>>
                              entry) {
                            List<LocationModel> locations = [];
                            entry.value.values
                                .forEach((list) => locations.addAll(list));

                            return MapEntry(
                                entry.key,
                                SliverStickyHeader(
                                  header: Container(
                                    decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.8),
                                        border: Border(
                                            bottom: BorderSide(
                                                color: Colors.grey.shade200,
                                                width: 1))),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 15, vertical: 10),
                                    alignment: Alignment.center,
                                    child: Text(
                                      entry.key,
                                      style:
                                          Theme.of(context).textTheme.subtitle,
                                    ),
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, i) {
                                        var item = locations[i];
                                        var timestamp =
                                            item.timestamp.toLocal();
                                        var hour = timestamp.hour;
                                        var dayHour = DateFormat.EEEE()
                                            .add_MMMd()
                                            .format(timestamp);
                                        var hourMap = _locationsIndex[dayHour];
                                        var selected = _selected?.id == item.id;

                                        var content = Column(children: [
                                          InkWell(
                                              onTap: () => setLocation(item),
                                              child: Container(
                                                padding: EdgeInsets.all(15),
                                                color: selected
                                                    ? Colors.grey[200]
                                                    : Colors.transparent,
                                                child: Row(children: [
                                                  Container(
                                                    width: 70,
                                                    child: Text(
                                                      DateFormat.jm()
                                                          .format(timestamp)
                                                          .toLowerCase(),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .subhead,
                                                      textAlign:
                                                          TextAlign.right,
                                                    ),
                                                  ),
                                                  Expanded(child: Container()),
                                                  Container(
                                                      width: 160,
                                                      child: Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .end,
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceEvenly,
                                                          children:
                                                              List.generate(
                                                            24,
                                                            (i) {
                                                              return Flexible(
                                                                  flex: 1,
                                                                  child: Row(
                                                                      children: [
                                                                        Expanded(
                                                                            child:
                                                                                Container(
                                                                          decoration: BoxDecoration(
                                                                              borderRadius: BorderRadius.vertical(top: Radius.circular(5), bottom: Radius.circular(5)),
                                                                              color: i == hour ? item.exposure ? Colors.red : Colors.grey[600] : Colors.grey[selected ? 400 : 300]),
                                                                          height: hourMap != null && hourMap.containsKey(i)
                                                                              ? 18
                                                                              : 5,
                                                                        )),
                                                                        SizedBox(
                                                                            width:
                                                                                3)
                                                                      ]));
                                                            },
                                                          ))),
                                                  Expanded(child: Container()),
                                                  Icon(
                                                      item.exposure
                                                          ? Icons.warning
                                                          : null,
                                                      color: item.exposure
                                                          ? Colors.orange
                                                          : Colors.grey)
                                                ]),
                                              )),
                                          Divider(height: 0),
                                        ]);

                                        return !item.exposure
                                            ? Dismissible(
                                                key: Key(item.id.toString()),
                                                background: Container(
                                                    color: Theme.of(context)
                                                        .primaryColor,
                                                    alignment:
                                                        Alignment.centerRight,
                                                    padding: EdgeInsets.only(
                                                        right: 15),
                                                    child: Icon(
                                                      Icons.delete,
                                                      color: Colors.white,
                                                    )),
                                                direction:
                                                    DismissDirection.endToStart,
                                                onDismissed: (direction) async {
                                                  await removeLocation(item);
                                                },
                                                child: content,
                                              )
                                            : content;
                                      },
                                      childCount: locations.length,
                                    ),
                                  ),
                                ));
                          })
                          .toList()
                          .map((e) => e.value)
                          .toList()))),
        ]));
  }
}

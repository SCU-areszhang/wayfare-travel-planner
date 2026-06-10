// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class AmapCanvasMarker {
  const AmapCanvasMarker({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.point,
    required this.color,
  });

  final String id;
  final String title;
  final String subtitle;
  final String category;
  final LatLng point;
  final Color color;
}

class AmapPickResult {
  const AmapPickResult({
    required this.point,
    required this.name,
    this.address,
  });

  final LatLng point;
  final String name;
  final String? address;
}

class AmapRouteSegment {
  const AmapRouteSegment({
    required this.points,
    required this.color,
  });

  final List<LatLng> points;
  final Color color;
}

class AmapCanvas extends StatefulWidget {
  const AmapCanvas({
    required this.jsKey,
    required this.securityCode,
    required this.markers,
    required this.routeSegments,
    required this.selectedPoint,
    required this.pickMode,
    required this.interactive,
    required this.primaryColor,
    required this.onMarkerTapped,
    required this.onPointPicked,
    this.visible = true,
    super.key,
  });

  final String jsKey;
  final String securityCode;
  final List<AmapCanvasMarker> markers;
  final List<AmapRouteSegment> routeSegments;
  final LatLng? selectedPoint;
  final bool pickMode;
  final bool interactive;
  final Color primaryColor;
  final ValueChanged<String> onMarkerTapped;
  final ValueChanged<AmapPickResult> onPointPicked;

  /// Whether the hosting page is currently shown. While hidden inside an
  /// IndexedStack the platform view is detached from the DOM, so render
  /// commands are deferred and replayed when the canvas becomes visible again.
  final bool visible;

  @override
  State<AmapCanvas> createState() => _AmapCanvasState();
}

class _AmapCanvasState extends State<AmapCanvas> with WidgetsBindingObserver {
  static var _bridgeInstalled = false;

  late final String _viewType;
  late final String _elementId;
  html.DivElement? _element;
  StreamSubscription<html.Event>? _statusSub;
  StreamSubscription<html.Event>? _pickSub;
  StreamSubscription<html.Event>? _markerSub;
  var _loading = true;
  String? _error;
  var _renderQueued = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _installBridge();
    _viewType = 'wayfare-amap-canvas-${identityHashCode(this)}';
    _elementId = 'wayfare-amap-element-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (viewId) {
      final element = html.DivElement()..id = _elementId;
      element.style
        ..width = '100%'
        ..height = '100%'
        ..minHeight = '320px'
        ..border = '0'
        ..background = '#eef3ef';
      _element = element;
      _syncElementState();
      _listenToElement(element);
      _queueRender();
      return element;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _queueRender();
  }

  @override
  void didChangeMetrics() {
    _queueRender();
  }

  @override
  void didUpdateWidget(AmapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncElementState();
    _queueRender();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusSub?.cancel();
    _pickSub?.cancel();
    _markerSub?.cancel();
    _dispatch({
      'type': 'destroy',
      'elementId': _elementId,
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        HtmlElementView(
          key: ValueKey(_elementId),
          viewType: _viewType,
        ),
        if (_loading || _error != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    if (_error == null)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                        size: 20,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error ?? 'Loading AMap JS API...',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _listenToElement(html.DivElement element) {
    _statusSub?.cancel();
    _pickSub?.cancel();
    _markerSub?.cancel();
    _statusSub = element.on['wayfare-amap-status'].listen((event) {
      final detail = _eventDetail(event);
      if (detail == null || !mounted) {
        return;
      }
      final state = detail['state'];
      setState(() {
        _loading = false;
        _error = state == 'error'
            ? (detail['message']?.toString() ?? 'AMap JS API failed to load.')
            : null;
      });
    });
    _pickSub = element.on['wayfare-amap-pick'].listen((event) {
      final detail = _eventDetail(event);
      if (detail == null) {
        return;
      }
      final lat = (detail['lat'] as num?)?.toDouble();
      final lng = (detail['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        return;
      }
      widget.onPointPicked(
        AmapPickResult(
          point: LatLng(lat, lng),
          name: (detail['name']?.toString().trim().isNotEmpty ?? false)
              ? detail['name'].toString()
              : 'Selected map point',
          address: detail['address']?.toString(),
        ),
      );
    });
    _markerSub = element.on['wayfare-amap-marker'].listen((event) {
      final detail = _eventDetail(event);
      final id = detail?['id']?.toString();
      if (id != null) {
        widget.onMarkerTapped(id);
      }
    });
  }

  Map<String, Object?>? _eventDetail(html.Event event) {
    if (event is! html.CustomEvent) {
      return null;
    }
    final detail = event.detail;
    if (detail is! String || detail.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(detail);
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  void _queueRender() {
    if (_renderQueued) {
      return;
    }
    _renderQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _renderQueued = false;
      if (!mounted || _element == null || !widget.visible) {
        // Hidden tabs have a zero-size detached container; rendering would
        // spin in the bridge retry loop. didUpdateWidget queues a fresh
        // render when the canvas becomes visible again.
        return;
      }
      setState(() {
        _loading = true;
        _error = null;
      });
      _dispatch(_payload());
    });
  }

  void _syncElementState() {
    final element = _element;
    if (element == null) {
      return;
    }
    element.style.pointerEvents = widget.interactive ? 'auto' : 'none';
  }

  Map<String, Object?> _payload() {
    return {
      'type': 'render',
      'elementId': _elementId,
      'key': widget.jsKey,
      'securityCode': widget.securityCode,
      'pickMode': widget.pickMode,
      'primaryColor': _hexColor(widget.primaryColor),
      'center': {
        'lng': 116.4074,
        'lat': 39.9042,
      },
      'markers': [
        for (final marker in widget.markers)
          {
            'id': marker.id,
            'title': marker.title,
            'subtitle': marker.subtitle,
            'category': marker.category,
            'lng': marker.point.longitude,
            'lat': marker.point.latitude,
            'color': _hexColor(marker.color),
          },
      ],
      'routes': [
        for (final segment in widget.routeSegments)
          {
            'color': _hexColor(segment.color),
            'points': [
              for (final point in segment.points)
                {
                  'lng': point.longitude,
                  'lat': point.latitude,
                },
            ],
          },
      ],
      'selected': widget.selectedPoint == null
          ? null
          : {
              'lng': widget.selectedPoint!.longitude,
              'lat': widget.selectedPoint!.latitude,
            },
    };
  }

  void _dispatch(Map<String, Object?> payload) {
    html.window.dispatchEvent(
      html.CustomEvent(
        'wayfare-amap-command',
        detail: jsonEncode(payload),
      ),
    );
  }

  static void _installBridge() {
    if (_bridgeInstalled) {
      return;
    }
    _bridgeInstalled = true;
    final script = html.ScriptElement()..text = _bridgeScript;
    html.document.head?.append(script);
  }

  String _hexColor(Color color) {
    final argb = color.toARGB32();
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }
}

const _bridgeScript = r'''
(function () {
  if (window.__wayfareAmapBridge) return;
  window.__wayfareAmapBridge = true;

  const states = {};
  let loadPromise = null;

  function safeParse(value) {
    try { return JSON.parse(value || '{}'); } catch (_) { return {}; }
  }

  function send(elementId, type, detail) {
    const element = document.getElementById(elementId);
    if (!element) return;
    element.dispatchEvent(new CustomEvent(type, {
      detail: JSON.stringify(detail || {})
    }));
  }

  function escapeHtml(value) {
    return String(value || '').replace(/[&<>"']/g, function (ch) {
      return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[ch];
    });
  }

  function pinHtml(color, title) {
    return [
      '<div style="position:relative;width:24px;height:24px;font-family:system-ui,-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;">',
      '<span style="position:absolute;left:3px;top:3px;width:18px;height:18px;border-radius:50%;background:', color, ';border:3px solid white;box-sizing:border-box;box-shadow:0 3px 10px rgba(0,0,0,.24);"></span>',
      '<span style="position:absolute;left:27px;top:1px;max-width:150px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;background:rgba(255,255,255,.94);border:1px solid rgba(15,23,42,.12);border-radius:999px;padding:3px 8px;color:#172033;font-size:12px;font-weight:650;box-shadow:0 4px 12px rgba(0,0,0,.14);">',
      escapeHtml(title),
      '</span></div>'
    ].join('');
  }

  function loadAmap(key, securityCode) {
    if (window.AMap) return Promise.resolve();
    if (loadPromise) return loadPromise;
    if (securityCode) {
      window._AMapSecurityConfig = { securityJsCode: securityCode };
    }
    loadPromise = new Promise(function (resolve, reject) {
      const script = document.createElement('script');
      script.async = true;
      script.defer = true;
      script.src = 'https://webapi.amap.com/maps?v=2.0&key=' +
        encodeURIComponent(key) + '&plugin=AMap.Scale,AMap.ToolBar,AMap.Geocoder';
      script.onload = function () { resolve(); };
      script.onerror = function () {
        loadPromise = null;
        reject(new Error('AMap JS API script failed to load'));
      };
      document.head.appendChild(script);
    });
    return loadPromise;
  }

  function createMap(payload) {
    const element = document.getElementById(payload.elementId);
    if (!element) throw new Error('Map container is missing');
    const map = new AMap.Map(payload.elementId, {
      center: [payload.center.lng, payload.center.lat],
      zoom: 11,
      viewMode: '2D',
      resizeEnable: true,
      mapStyle: 'amap://styles/normal'
    });
    try { map.addControl(new AMap.Scale()); } catch (_) {}
    try { map.addControl(new AMap.ToolBar()); } catch (_) {}
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(function (position) {
        const current = states[payload.elementId];
        if (!current || current.didFitView) return;
        try {
          map.setZoomAndCenter(13, [
            position.coords.longitude,
            position.coords.latitude
          ]);
        } catch (_) {}
      }, function () {}, {
        enableHighAccuracy: true,
        timeout: 6000,
        maximumAge: 300000
      });
    }
    const state = {
      map: map,
      container: element,
      geocoder: null,
      overlays: [],
      pickMode: !!payload.pickMode,
      resolvingPick: false,
      didFitView: false,
      signature: ''
    };
    states[payload.elementId] = state;
    map.on('click', function (event) {
      const current = states[payload.elementId];
      if (!current || !current.pickMode) return;
      if (current.resolvingPick) return;
      current.resolvingPick = true;
      resolvePickedPoint(payload.elementId, event.lnglat);
    });
    return state;
  }

  function resolvePickedPoint(elementId, lnglat) {
    const lng = lnglat.getLng();
    const lat = lnglat.getLat();
    const fallback = {
      lng: lng,
      lat: lat,
      name: 'Selected map point',
      address: ''
    };
    const state = states[elementId];
    function sendPick(detail) {
      if (state) state.resolvingPick = false;
      send(elementId, 'wayfare-amap-pick', detail);
    }
    if (!window.AMap || !AMap.Geocoder || !state) {
      sendPick(fallback);
      return;
    }
    try {
      state.geocoder = state.geocoder || new AMap.Geocoder({
        radius: 300,
        extensions: 'all'
      });
      state.geocoder.getAddress(lnglat, function (status, result) {
        if (status !== 'complete' || !result || !result.regeocode) {
          sendPick(fallback);
          return;
        }
        const regeocode = result.regeocode;
        const pois = Array.isArray(regeocode.pois) ? regeocode.pois : [];
        const aois = Array.isArray(regeocode.aois) ? regeocode.aois : [];
        const nearest = pois[0] || aois[0] || null;
        const formattedAddress = regeocode.formattedAddress || '';
        sendPick({
          lng: lng,
          lat: lat,
          name: nearest && nearest.name ? nearest.name : (formattedAddress || fallback.name),
          address: formattedAddress,
          poiType: nearest && nearest.type ? nearest.type : '',
          poiDistance: nearest && nearest.distance ? nearest.distance : ''
        });
      });
    } catch (_) {
      sendPick(fallback);
    }
  }

  function render(payload) {
    const element = document.getElementById(payload.elementId);
    if (!element) throw new Error('Map container is missing');
    const rect = element.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) {
      window.setTimeout(function () {
        window.dispatchEvent(new CustomEvent('wayfare-amap-command', {
          detail: JSON.stringify(payload)
        }));
      }, 80);
      return;
    }
    let state = states[payload.elementId];
    if (state && state.container !== element) {
      // Flutter recreated the platform view element; the old map instance is
      // bound to a detached node and can never paint again.
      try { state.map.destroy(); } catch (_) {}
      delete states[payload.elementId];
      state = null;
    }
    state = state || createMap(payload);
    const map = state.map;
    state.pickMode = !!payload.pickMode;
    try { map.resize(); } catch (_) {}

    const markerSignature = JSON.stringify({
      markers: (payload.markers || []).map(function (item) {
        return [item.id, item.lng, item.lat];
      }),
      routes: payload.routes || [],
      selected: payload.selected || null
    });
    if (markerSignature !== state.signature) {
      state.signature = markerSignature;
      state.didFitView = false;
    }

    try { map.clearMap(); } catch (_) {}
    state.overlays = [];

    (payload.markers || []).forEach(function (item) {
      const marker = new AMap.Marker({
        position: [item.lng, item.lat],
        title: item.title,
        content: pinHtml(item.color || '#2563eb', item.title),
        anchor: 'center',
        zIndex: item.category === 'Itinerary' ? 110 : 100
      });
      marker.on('click', function () {
        send(payload.elementId, 'wayfare-amap-marker', { id: item.id });
      });
      state.overlays.push(marker);
      map.add(marker);
    });

    if (payload.selected) {
      const selected = new AMap.Marker({
        position: [payload.selected.lng, payload.selected.lat],
        title: 'Selected point',
        content: pinHtml('#c026d3', 'Selected'),
        anchor: 'center',
        zIndex: 120
      });
      state.overlays.push(selected);
      map.add(selected);
    }

    (payload.routes || []).forEach(function (segment) {
      const points = segment.points || [];
      if (points.length < 2) return;
      const line = new AMap.Polyline({
        path: points.map(function (item) { return [item.lng, item.lat]; }),
        strokeColor: segment.color || payload.primaryColor || '#2563eb',
        strokeOpacity: 0.88,
        strokeWeight: 7,
        lineJoin: 'round'
      });
      state.overlays.push(line);
      map.add(line);
    });

    if (!state.didFitView && state.overlays.length) {
      state.didFitView = true;
      try { map.setFitView(state.overlays, false, [64, 64, 64, 64]); } catch (_) {}
    }
    window.requestAnimationFrame(function () {
      try { map.resize(); } catch (_) {}
    });
  }

  window.addEventListener('wayfare-amap-command', function (event) {
    const payload = safeParse(event.detail);
    if (payload.type === 'destroy') {
      const state = states[payload.elementId];
      if (state) {
        try { state.map.destroy(); } catch (_) {}
        delete states[payload.elementId];
      }
      return;
    }
    if (payload.type !== 'render') return;
    loadAmap(payload.key, payload.securityCode)
      .then(function () {
        render(payload);
        send(payload.elementId, 'wayfare-amap-status', { state: 'ready' });
      })
      .catch(function (error) {
        send(payload.elementId, 'wayfare-amap-status', {
          state: 'error',
          message: error && error.message ? error.message : 'AMap JS API failed to load'
        });
      });
  });
})();
''';

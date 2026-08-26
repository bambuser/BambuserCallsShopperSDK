//
//  EmbedHTMLBuilder.swift
//  BambuserCallsShopper
//

import Foundation

internal enum EmbedHTMLBuilder {

    /// Embed constructor options sourced from `BambuserCallConfiguration`
    /// plus per-`show()` overrides.
    struct Options {
        var orgId: String
        var embedUrl: URL
        var connectId: String?
        var queue: String?
        var triggers: [String]
        var floatingNavigationMode: String
        var floatingFillMode: String

        var locale: String?
        var data: BambuserJSONValue?
        var trackingTags: BambuserJSONValue?

        var dropInEnabled: Bool?
        var bookingsEnabled: Bool?
        var openBookingPage: Bool
        var bookingServiceIds: [String]?
        var bookingResourceId: String?
        var bookingIframeUrl: String?

        var enableScanning: Bool
        var merchantBaseUrl: String?
        var disableCoBrowsing: Bool
        var themeId: String?
        var allowFirstPartyCookies: Bool?
        var disableDataLayerInterceptions: Bool

        var subscriptions: BambuserCallSubscriptions
    }

    static func makeHTML(options o: Options) -> String {
        let configLiteral = buildEmbedConfigLiteral(o)
        let onBlocks = buildOnBlocks(subs: o.subscriptions)
        let handledByCase = handledByCaseLiteral(subs: o.subscriptions)
        let catchAll = o.subscriptions.catchAllOther ? "true" : "false"

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
        </head>
        <body>
        <script>
        window.__bambuserPendingNavigations = window.__bambuserPendingNavigations || [];
        window.notifyBambuserProductNavigation = function(externalId) {
          if (typeof externalId !== 'string' || !externalId) return;
          if (window.oneToOneEmbed && typeof window.oneToOneEmbed.notifyProductNavigation === 'function') {
            try {
              window.oneToOneEmbed.notifyProductNavigation({externalId: externalId});
            } catch (e) {
              console.error('[bambuser] notifyProductNavigation failed', e);
            }
          } else {
            window.__bambuserPendingNavigations.push(externalId);
          }
        };

        window.onBambuserOneToOneReady = function(BambuserOneToOneEmbed) {
          var oneToOneEmbed = new BambuserOneToOneEmbed(\(configLiteral));
          window.oneToOneEmbed = oneToOneEmbed;
          window.BambuserOneToOneEmbed = BambuserOneToOneEmbed;

          if (window.__bambuserPendingNavigations.length) {
            window.__bambuserPendingNavigations.splice(0).forEach(function(sku) {
              try { oneToOneEmbed.notifyProductNavigation({externalId: sku}); } catch (e) {}
            });
          }

          oneToOneEmbed.on('close', function() {
            __post('close');
          });

        \(onBlocks)

          // Emitter override — forwards call-state events plus any
          // event not explicitly subscribed above (if catchAllOther).
          try {
            var emitter = oneToOneEmbed.events;
            if (emitter && typeof emitter.emit === 'function') {
              var handledByCase = \(handledByCase);
              var callStateEvents = {
                'call-started': 1, 'call-starting': 1, 'call-connecting': 1, 'call-ringing': 1,
                'call-connected': 1, 'call-active': 1, 'call-accepted': 1, 'connected': 1,
                'call-ended': 1, 'call-end': 1, 'call-disconnected': 1, 'call-rejected': 1,
                'disconnected': 1, 'ended': 1
              };
              var catchAllOther = \(catchAll);
              var originalEmit = emitter.emit.bind(emitter);
              emitter.emit = function(name) {
                var rest = Array.prototype.slice.call(arguments, 1);
                if (!handledByCase[name]) {
                  if (callStateEvents[name] || catchAllOther) {
                    var payload;
                    try {
                      payload = JSON.parse(JSON.stringify(rest.length === 1 ? rest[0] : rest));
                    } catch (e) {
                      payload = String(rest[0]);
                    }
                    __post(name, payload === undefined ? null : payload);
                  }
                }
                return originalEmit.apply(null, arguments);
              };
            }
          } catch (e) {}
        };

        window.__bambuserCartCallbackSeq = 0;
        function __nextCallbackId() {
          window.__bambuserCartCallbackSeq += 1;
          return 'cb_' + window.__bambuserCartCallbackSeq;
        }

        // === Generic factory-spec bridge ==================================
        window.__bambuserApplyFactorySpec = function(factory, spec) {
          if (!spec || !spec.calls) return factory;
          var current = factory;
          spec.calls.forEach(function(call) {
            var args = (call.args || []).slice();
            if (call.factory) {
              (function(sub) {
                args.push(function(f) {
                  return window.__bambuserApplyFactorySpec(f, sub);
                });
              })(call.factory);
            } else if (call.items) {
              (function(items) {
                args.push(function(itemFactory) {
                  return items.map(function(item) {
                    var itemArgs = item.factoryArgs || [];
                    var starting = (typeof itemFactory === 'function')
                      ? itemFactory.apply(null, itemArgs)
                      : itemFactory;
                    return window.__bambuserApplyFactorySpec(
                      starting,
                      item.spec || { calls: [] }
                    );
                  });
                });
              })(call.items);
            }
            if (typeof current[call.method] !== 'function') {
              console.warn('[bambuser] applyFactorySpec: no method', call.method);
              return;
            }
            current = current[call.method].apply(current, args);
          });
          return current;
        };

        window.__bambuserApplyToCallback = function(callbackKey, spec, deleteAfter) {
          var cb = window[callbackKey];
          if (typeof cb !== 'function') {
            console.warn('[bambuser] applyToCallback: no callback', callbackKey);
            return;
          }
          try {
            cb(function(factory) {
              return window.__bambuserApplyFactorySpec(factory, spec);
            });
          } catch (e) {
            console.error('[bambuser] applyToCallback failed', callbackKey, e);
          }
          if (deleteAfter !== false) {
            try { delete window[callbackKey]; } catch (e) { window[callbackKey] = undefined; }
          }
        };

        // Invoke a stashed callback with a builder that throws — the
        // "verify function" pattern. The embed catches the throw and
        // shows the message to the agent.
        window.__bambuserApplyToCallbackWithError = function(callbackKey, errorMessage, deleteAfter) {
          var cb = window[callbackKey];
          if (typeof cb !== 'function') {
            console.warn('[bambuser] applyToCallbackWithError: no callback', callbackKey);
            return;
          }
          try {
            cb(function() {
              throw new Error(errorMessage || 'error');
            });
          } catch (e) {
            // Outer callback threw synchronously (unusual — the
            // builder-side throw is the intended path).
            console.error('[bambuser] applyToCallbackWithError sync failure', callbackKey, e);
          }
          if (deleteAfter !== false) {
            try { delete window[callbackKey]; } catch (e) { window[callbackKey] = undefined; }
          }
        };

        // `oneToOneEmbed[method](...primaryArgs, () => { throw ... })`
        // — how the embed surfaces "product not available" from
        // provide-product-data.
        window.__bambuserInvokeEmbedMethodWithError = function(method, primaryArgs, errorMessage) {
          if (!window.oneToOneEmbed || typeof window.oneToOneEmbed[method] !== 'function') {
            console.warn('[bambuser] invokeEmbedMethodWithError: not available', method);
            return;
          }
          var args = (primaryArgs || []).slice();
          args.push(function() {
            throw new Error(errorMessage || 'error');
          });
          try {
            window.oneToOneEmbed[method].apply(window.oneToOneEmbed, args);
          } catch (e) {
            console.error('[bambuser] invokeEmbedMethodWithError sync failure', method, e);
          }
        };

        window.__bambuserInvokeEmbedMethod = function(method, primaryArgs, spec) {
          if (!window.oneToOneEmbed || typeof window.oneToOneEmbed[method] !== 'function') {
            console.warn('[bambuser] invokeEmbedMethod: not available', method);
            return;
          }
          var args = (primaryArgs || []).slice();
          if (spec) {
            args.push(function(factory) {
              return window.__bambuserApplyFactorySpec(factory, spec);
            });
          }
          try {
            window.oneToOneEmbed[method].apply(window.oneToOneEmbed, args);
          } catch (e) {
            console.error('[bambuser] invokeEmbedMethod failed', method, e);
          }
        };

        // Report a shopper-driven event to the widget. CUSTOMER_EVENTS
        // is looked up by name at call time so future keys work
        // without an SDK update.
        window.__bambuserNotifyCustomerEvent = function(constantName, payload) {
          if (!window.oneToOneEmbed
              || typeof window.oneToOneEmbed.notifyCustomerEvent !== 'function') {
            console.warn('[bambuser] notifyCustomerEvent not available');
            return;
          }
          var cls = window.BambuserOneToOneEmbed;
          if (!cls || !cls.CUSTOMER_EVENTS) {
            console.warn('[bambuser] CUSTOMER_EVENTS constants not exposed by this embed build');
            return;
          }
          var eventType = cls.CUSTOMER_EVENTS[constantName];
          if (eventType == null) {
            console.warn('[bambuser] unknown CUSTOMER_EVENTS key:', constantName);
            return;
          }
          try {
            window.oneToOneEmbed.notifyCustomerEvent(eventType, payload);
          } catch (e) {
            // Embed throws on malformed input — surface but do not crash.
            console.error('[bambuser] notifyCustomerEvent failed', constantName, e);
          }
        };

        window.__bambuserInvokeEmbedAsync = function(requestId, method, primaryArgs) {
          function reply(ok, value, error) {
            __post('__async-response', {
              requestId: requestId,
              ok: ok,
              value: value !== undefined ? value : null,
              error: error != null ? String(error) : null
            });
          }
          if (!window.oneToOneEmbed || typeof window.oneToOneEmbed[method] !== 'function') {
            reply(false, null, 'method-not-available: ' + method);
            return;
          }
          try {
            var result = window.oneToOneEmbed[method].apply(window.oneToOneEmbed, primaryArgs || []);
            if (result && typeof result.then === 'function') {
              result.then(function(v) {
                try { reply(true, JSON.parse(JSON.stringify(v))); }
                catch (e) { reply(true, null); }
              }, function(err) {
                reply(false, null, err && err.message ? err.message : String(err));
              });
            } else {
              try { reply(true, JSON.parse(JSON.stringify(result))); }
              catch (e) { reply(true, null); }
            }
          } catch (e) {
            reply(false, null, e && e.message ? e.message : String(e));
          }
        };

        function __post(event, payload) {
          try {
            window.webkit.messageHandlers.nativeBridge.postMessage(
              JSON.stringify({event: event, payload: payload === undefined ? null : payload})
            );
          } catch (e) {}
        }
        </script>
        <script async src="\(o.embedUrl.absoluteString)"></script>
        </body>
        </html>
        """
    }

    // MARK: - JS block builders

    /// Delegate-mapped events are always installed; data-source
    /// events are gated on their handler being non-nil.
    private static func buildOnBlocks(subs: BambuserCallSubscriptions) -> String {
        var out: [String] = []

        // Fire-and-forget (delegate-mapped)

        out.append("""
          oneToOneEmbed.on('goto-checkout', function(event) {
            __post('goto-checkout', event || null);
          });
        """)
        out.append("""
          oneToOneEmbed.on('goto-chat', function() {
            __post('goto-chat');
          });
        """)
        out.append("""
          oneToOneEmbed.on('surf-behind-to', function(url) {
            __post('surf-behind-to', { url: url });
          });
        """)
        out.append("""
          oneToOneEmbed.on('queue-is-open', function(data) {
            __post('queue-is-open', {
              isOpen: true,
              nextCloseTime: data && data.nextCloseTime != null ? data.nextCloseTime : null
            });
          });
        """)
        out.append("""
          oneToOneEmbed.on('queue-is-closed', function(data) {
            __post('queue-is-closed', {
              isOpen: false,
              nextOpenTime: data && data.nextOpenTime != null ? data.nextOpenTime : null
            });
          });
        """)
        out.append("""
          oneToOneEmbed.on('agents-online', function(data) {
            __post('agents-online', {
              numberOfAgentsOnline: data && data.numberOfAgentsOnline != null ? data.numberOfAgentsOnline : 0,
              queueId: data && (data.queueId || data.queue) || null
            });
          });
        """)
        out.append("""
          oneToOneEmbed.on('queue-estimated-waiting-time', function(data) {
            __post('queue-estimated-waiting-time', {
              estimatedWaitingTime: data && data.estimatedWaitingTime != null ? data.estimatedWaitingTime : 0,
              agents: data && data.agents != null ? data.agents : 0,
              place:  data && data.place  != null ? data.place  : 0,
              queueId: data && (data.queueId || data.queue) || null
            });
          });
        """)
        out.append("""
          oneToOneEmbed.on('tracking-event', function(payload) {
            try {
              __post('tracking-event', JSON.parse(JSON.stringify(payload || {})));
            } catch (e) {
              __post('tracking-event', {});
            }
          });
        """)

        // Data-source (handler-mapped) — only when a handler is set

        if subs.shouldAddToCart {
            out.append("""
              oneToOneEmbed.on('should-add-item-to-cart', function(event, callback) {
                var id = __nextCallbackId();
                window[id] = callback;
                __post('should-add-item-to-cart', { callbackId: id, payload: event });
              });
            """)
        }
        if subs.shouldUpdateCart {
            out.append("""
              oneToOneEmbed.on('should-update-item-in-cart', function(event, callback) {
                var id = __nextCallbackId();
                window[id] = callback;
                __post('should-update-item-in-cart', { callbackId: id, payload: event });
              });
            """)
        }
        if subs.provideSearchData {
            out.append("""
              oneToOneEmbed.on('provide-search-data', function(searchRequest, searchResponse) {
                var id = __nextCallbackId();
                window[id] = searchResponse;
                __post('provide-search-data', {
                  callbackId: id,
                  term: (searchRequest && searchRequest.term) || '',
                  page:  (searchRequest && (searchRequest.page != null ? searchRequest.page : 1)) || 1
                });
              });
            """)
        }
        if subs.provideProductData {
            out.append("""
              oneToOneEmbed.on('provide-product-data', function(event) {
                var products = (event && event.products) || [];
                var refs = [];
                for (var i = 0; i < products.length; i++) {
                  var p = products[i] || {};
                  refs.push({
                    ref: p.ref != null ? String(p.ref) : '',
                    type: p.type != null ? String(p.type) : '',
                    id: p.id != null ? String(p.id) : ''
                  });
                }
                __post('provide-product-data', { products: refs });
              });
            """)
        }

        return out.joined(separator: "\n")
    }

    /// Events already handled explicitly via `.on(...)`, so the
    /// emitter override doesn't double-post them.
    private static func handledByCaseLiteral(subs: BambuserCallSubscriptions) -> String {
        var names: [String] = [
            "close",
            "goto-checkout",
            "goto-chat",
            "surf-behind-to",
            "queue-is-open",
            "queue-is-closed",
            "agents-online",
            "queue-estimated-waiting-time",
            "tracking-event",
        ]
        if subs.shouldAddToCart    { names.append("should-add-item-to-cart") }
        if subs.shouldUpdateCart   { names.append("should-update-item-in-cart") }
        if subs.provideProductData { names.append("provide-product-data") }
        if subs.provideSearchData  { names.append("provide-search-data") }
        let entries = names.map { "'\($0)': 1" }.joined(separator: ", ")
        return "{ \(entries) }"
    }

    /// Build the `new BambuserOneToOneEmbed({...})` config literal.
    /// Nil / empty fields are dropped.
    private static func buildEmbedConfigLiteral(_ o: Options) -> String {
        var fields: [String] = []
        fields.append("orgId: '\(escapeJS(o.orgId))'")
        fields.append("disableDataLayerInterceptions: \(o.disableDataLayerInterceptions ? "true" : "false")")
        fields.append("triggers: \(jsArray(o.triggers))")
        if let connectId = o.connectId, !connectId.isEmpty {
            fields.append("connectId: '\(escapeJS(connectId))'")
        }
        if let queue = o.queue, !queue.isEmpty {
            fields.append("queue: '\(escapeJS(queue))'")
        }
        if let locale = o.locale, !locale.isEmpty {
            fields.append("locale: '\(escapeJS(locale))'")
        }
        if let data = o.data, case .object(let map) = data, !map.isEmpty {
            fields.append("data: \(jsonLiteral(data))")
        }
        if let tags = o.trackingTags, case .array(let arr) = tags, !arr.isEmpty {
            fields.append("trackingTags: \(jsonLiteral(tags))")
        }

        if let v = o.dropInEnabled              { fields.append("dropInEnabled: \(v ? "true" : "false")") }
        if let v = o.bookingsEnabled            { fields.append("bookingsEnabled: \(v ? "true" : "false")") }
        if o.openBookingPage                    { fields.append("openBookingPage: true") }
        if let ids = o.bookingServiceIds, !ids.isEmpty {
            fields.append("bookingServiceIds: \(jsArray(ids))")
        }
        if let id = o.bookingResourceId, !id.isEmpty {
            fields.append("bookingResourceId: '\(escapeJS(id))'")
        }
        if let url = o.bookingIframeUrl, !url.isEmpty {
            fields.append("bookingIframeUrl: '\(escapeJS(url))'")
        }
        if o.enableScanning                     { fields.append("enableScanning: true") }
        if let url = o.merchantBaseUrl, !url.isEmpty {
            fields.append("merchantBaseUrl: '\(escapeJS(url))'")
        }
        if o.disableCoBrowsing                  { fields.append("disableCoBrowsing: true") }
        if let id = o.themeId, !id.isEmpty {
            fields.append("themeId: '\(escapeJS(id))'")
        }
        if let v = o.allowFirstPartyCookies     { fields.append("allowFirstPartyCookies: \(v ? "true" : "false")") }

        fields.append(
            "floatingPlayer: { navigationMode: '\(escapeJS(o.floatingNavigationMode))', webViewFillMode: '\(escapeJS(o.floatingFillMode))' }"
        )

        return "{ " + fields.joined(separator: ", ") + " }"
    }

    // MARK: - Document-start shim + base URL

    static func makeDocumentStartShim(injectsLegacyGetUserMediaShim: Bool) -> String {
        var src = ""
        if injectsLegacyGetUserMediaShim {
            src += """
            window.getUserMedia = function(constraints, successCallback, errorCallback) {
                if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
                    navigator.mediaDevices.getUserMedia(constraints).then(successCallback).catch(errorCallback);
                } else if (errorCallback) {
                    errorCallback(new DOMException('getUserMedia not supported', 'NotSupportedError'));
                }
            };

            """
        }
        src += """
        window.addEventListener('message', function(event) {
            try {
                var raw = event.data;
                var str = (typeof raw === 'string') ? raw : JSON.stringify(raw);
                if (str && str.indexOf('viddget') !== -1) {
                    window.webkit.messageHandlers.nativeBridge.postMessage(
                        JSON.stringify({event: 'iframe-message', detail: str, origin: event.origin})
                    );
                }
            } catch(e) {}
        });
        """
        return src
    }

    static func baseURL(for embedUrl: URL) -> URL? {
        guard let scheme = embedUrl.scheme, let host = embedUrl.host else { return nil }
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = embedUrl.port
        return components.url
    }

    // MARK: - JS emission helpers

    private static func escapeJS(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func jsArray(_ items: [String]) -> String {
        let escaped = items.map { "'\(escapeJS($0))'" }.joined(separator: ", ")
        return "[\(escaped)]"
    }

    private static func jsonLiteral(_ value: BambuserJSONValue) -> String {
        let encoder = JSONEncoder()
        guard
            let data = try? encoder.encode(value),
            let s = String(data: data, encoding: .utf8)
        else { return "null" }
        return s
    }
}

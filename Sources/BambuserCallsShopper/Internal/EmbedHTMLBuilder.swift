//
//  EmbedHTMLBuilder.swift
//  BambuserCallsShopper
//

import Foundation

internal enum EmbedHTMLBuilder {

    static func makeHTML(
        orgId: String,
        embedUrl: URL,
        triggers: [String],
        floatingNavigationMode: String,
        floatingFillMode: String
    ) -> String {
        let triggersJSArray = jsArray(triggers)

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
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
          var oneToOneEmbed = new BambuserOneToOneEmbed({
            orgId: '\(escapeJS(orgId))',
            triggers: \(triggersJSArray),
            floatingPlayer: {
              navigationMode: '\(escapeJS(floatingNavigationMode))',
              webViewFillMode: '\(escapeJS(floatingFillMode))'
            }
          });
          window.oneToOneEmbed = oneToOneEmbed;

          if (window.__bambuserPendingNavigations.length) {
            window.__bambuserPendingNavigations.splice(0).forEach(function(sku) {
              try { oneToOneEmbed.notifyProductNavigation({externalId: sku}); } catch (e) {}
            });
          }

          oneToOneEmbed.on('close', function() {
            __post('close');
          });
          oneToOneEmbed.on('surf-behind-to', function(url) {
            __post('surf-behind-to', { url: url });
          });
          oneToOneEmbed.on('goto-checkout', function(event) {
            __post('goto-checkout', event || null);
          });
          oneToOneEmbed.on('should-add-item-to-cart', function(event, callback) {
            var id = __nextCallbackId();
            window[id] = callback;
            __post('should-add-item-to-cart', { callbackId: id, payload: event });
          });
          oneToOneEmbed.on('should-update-item-in-cart', function(event, callback) {
            var id = __nextCallbackId();
            window[id] = callback;
            __post('should-update-item-in-cart', { callbackId: id, payload: event });
          });

          // Catch-all: forward any event not already handled above through
          // the embed's internal EventEmitter.
          try {
            var emitter = oneToOneEmbed.events;
            if (emitter && typeof emitter.emit === 'function') {
              var handledByCase = {
                'close': 1,
                'surf-behind-to': 1,
                'goto-checkout': 1,
                'should-add-item-to-cart': 1,
                'should-update-item-in-cart': 1
              };
              var originalEmit = emitter.emit.bind(emitter);
              emitter.emit = function(name) {
                var rest = Array.prototype.slice.call(arguments, 1);
                if (!handledByCase[name]) {
                  var payload;
                  try {
                    payload = JSON.parse(JSON.stringify(rest.length === 1 ? rest[0] : rest));
                  } catch (e) {
                    payload = String(rest[0]);
                  }
                  __post(name, payload === undefined ? null : payload);
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

        function __post(event, payload) {
          try {
            window.webkit.messageHandlers.nativeBridge.postMessage(
              JSON.stringify({event: event, payload: payload === undefined ? null : payload})
            );
          } catch (e) {}
        }
        </script>
        <script async src="\(embedUrl.absoluteString)"></script>
        </body>
        </html>
        """
    }

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

    private static func escapeJS(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func jsArray(_ items: [String]) -> String {
        let escaped = items.map { "'\(escapeJS($0))'" }.joined(separator: ", ")
        return "[\(escaped)]"
    }
}

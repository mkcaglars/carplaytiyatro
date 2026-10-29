import Foundation

/// Web sayfasındaki <video> öğesini kontrol eden JavaScript parçaları.
enum PlayerScripts {
    static let messageName = "tiyatro"

    /// Her sayfa yüklemesinde enjekte edilir: oynatma durumunu uygulamaya bildirir.
    static let bootstrap = """
    (function() {
      if (window.__tiyatroReady) { return; }
      window.__tiyatroReady = true;
      function post(state) {
        try { window.webkit.messageHandlers.\(messageName).postMessage(state); } catch (e) {}
      }
      window.__tiyatroVideo = function() {
        var videos = Array.prototype.slice.call(document.querySelectorAll('video'));
        var playing = videos.filter(function(v) { return !v.paused; });
        if (playing.length) { return playing[0]; }
        videos.sort(function(a, b) {
          return (b.clientWidth * b.clientHeight) - (a.clientWidth * a.clientHeight);
        });
        return videos[0] || null;
      };
      document.addEventListener('playing', function() { post('playing'); }, true);
      document.addEventListener('pause', function() { post('paused'); }, true);
      document.addEventListener('ended', function() { post('paused'); }, true);
    })();
    """

    static let togglePlay = """
    (function() {
      var v = window.__tiyatroVideo && window.__tiyatroVideo();
      if (!v) { return; }
      if (v.paused) { v.play(); } else { v.pause(); }
    })();
    """

    static let pause = """
    (function() {
      var v = window.__tiyatroVideo && window.__tiyatroVideo();
      if (v) { v.pause(); }
    })();
    """

    static func seek(by seconds: Double) -> String {
        """
        (function() {
          var v = window.__tiyatroVideo && window.__tiyatroVideo();
          if (!v) { return; }
          v.currentTime = Math.max(0, v.currentTime + (\(seconds)));
        })();
        """
    }

    /// "Sinema modu": videoyu tüm ekrana yayar, sayfanın geri kalanını gizler.
    static func cinema(_ enabled: Bool) -> String {
        """
        (function(on) {
          var id = 'tiyatro-cinema';
          var el = document.getElementById(id);
          if (!on) { if (el) { el.remove(); } return; }
          if (el) { return; }
          el = document.createElement('style');
          el.id = id;
          el.textContent = 'html, body { overflow: hidden !important; background: #000 !important; }' +
            'video { position: fixed !important; top: 0 !important; left: 0 !important;' +
            ' width: 100vw !important; height: 100vh !important; max-width: none !important;' +
            ' max-height: none !important; z-index: 2147483647 !important;' +
            ' background: #000 !important; object-fit: contain !important; transform: none !important; }';
          (document.head || document.documentElement).appendChild(el);
        })(\(enabled ? "true" : "false"));
        """
    }
}

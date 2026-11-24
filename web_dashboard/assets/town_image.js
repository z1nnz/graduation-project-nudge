(function(root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.NudgeTownImage = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function() {
  'use strict';
  const handlers = new WeakMap();
  function preferred(path) { return path.replace(/\.(png|jpe?g)$/i, '.webp'); }
  function load(image, fallbackPath, onFinalError) {
    if (handlers.has(image)) image.removeEventListener?.('error', handlers.get(image));
    const webpPath = preferred(fallbackPath);
    let triedFallback = false;
    const failed = () => {
      if (!triedFallback && webpPath !== fallbackPath) {
        triedFallback = true;
        image.src = fallbackPath;
      } else {
        image.removeEventListener?.('error', failed);
        handlers.delete(image);
        onFinalError?.();
      }
    };
    handlers.set(image, failed);
    image.addEventListener('error', failed);
    image.src = webpPath;
    return webpPath;
  }
  return { preferred, load };
});

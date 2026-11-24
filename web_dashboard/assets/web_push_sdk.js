(() => {
  "use strict";
  const script = document.createElement("script");
  script.src = "https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js";
  window.nudgeWebPushMessagingSdk = new Promise((resolve, reject) => {
    script.onload = resolve;
    script.onerror = reject;
    document.head.append(script);
  });
})();

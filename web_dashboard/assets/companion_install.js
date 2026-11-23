(function(root) {
  'use strict';
  let deferredPrompt = null;
  let busy = false;
  let browserReportedInstalled = false;
  const byId = id => document.getElementById(id);
  function standalone() {
    return root.matchMedia?.('(display-mode: standalone)').matches || root.navigator.standalone === true;
  }
  function renderInstall() {
    const button = byId('companionInstallButton');
    if (!button) return;
    button.hidden = Boolean(standalone() || browserReportedInstalled);
    button.disabled = busy;
    byId('companionInstallStatus').textContent = browserReportedInstalled
      ? '瀏覽器已回報安裝完成' : standalone()
      ? '已在獨立視窗開啟' : deferredPrompt ? '瀏覽器已提供安裝選項' : '安裝方式依瀏覽器而異，也可以直接使用網頁';
  }
  function renderNetwork() {
    const status = byId('companionNetworkStatus');
    if (status) status.textContent = root.navigator.onLine === false
      ? '瀏覽器回報離線；資料可能尚未同步。請保留頁面並查看各功能的同步狀態。'
      : '瀏覽器回報可連線；不代表 Cloud 已確認，請查看各功能的同步狀態。';
  }
  root.addEventListener('beforeinstallprompt', event => {
    event.preventDefault();
    deferredPrompt = event;
    renderInstall();
  });
  root.addEventListener('appinstalled', () => {
    deferredPrompt = null;
    browserReportedInstalled = true;
    renderInstall();
  });
  root.addEventListener('online', renderNetwork);
  root.addEventListener('offline', renderNetwork);
  root.addEventListener('pageshow', () => { renderInstall(); renderNetwork(); });
  const mode = root.matchMedia?.('(display-mode: standalone)');
  mode?.addEventListener?.('change', renderInstall);
  function start() {
    const button = byId('companionInstallButton');
    if (!button || button.dataset.installBound) return;
    button.dataset.installBound = 'true';
    button.addEventListener('click', async () => {
      byId('companionInstallHelp').hidden = false;
      if (busy || !deferredPrompt) return;
      const prompt = deferredPrompt;
      deferredPrompt = null; // A browser installation event can only be used once.
      busy = true;
      renderInstall();
      let message;
      try {
        await prompt.prompt();
        const choice = await prompt.userChoice;
        message = choice?.outcome === 'accepted'
          ? '已送出安裝要求，請確認瀏覽器結果。'
          : '這次未安裝；仍可繼續使用網頁。';
      } catch (_) {
        message = '未能開啟安裝視窗，請使用下方手動方式。';
      } finally {
        busy = false;
        renderInstall();
        if (!browserReportedInstalled) byId('companionInstallStatus').textContent = message;
      }
    });
    renderInstall(); renderNetwork();
  }
  document.addEventListener('DOMContentLoaded', start);
  start();
})(typeof globalThis !== 'undefined' ? globalThis : this);

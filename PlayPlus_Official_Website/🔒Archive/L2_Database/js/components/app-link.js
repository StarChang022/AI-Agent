(function () {
  var linkElements = document.querySelectorAll('.app-link');
  if (linkElements.length === 0) return;

  var userAgent = navigator.userAgent;
  var platform = navigator.platform;

  var iosUrl = 'https://apps.apple.com/tw/app/id6745397830';
  var androidUrl = 'https://play.google.com/store/apps/details?id=com.playplus.tfif';

  var isMac = /Macintosh|MacIntel|MacPPC|Mac68K/.test(userAgent) || /Mac/.test(platform);
  var isWin = /Win32|Win64|Windows|WinCE/.test(userAgent) || /Win/.test(platform);

  linkElements.forEach(function (linkElement) {
    if (isMac || isWin) {
      linkElement.style.display = 'none';
    } else if (/android/i.test(userAgent)) {
      linkElement.href = androidUrl;
    } else if (/iPad|iPhone|iPod/.test(userAgent) && !window.MSStream) {
      linkElement.href = iosUrl;
    } else {
      linkElement.style.display = 'none';
    }
  });
})();

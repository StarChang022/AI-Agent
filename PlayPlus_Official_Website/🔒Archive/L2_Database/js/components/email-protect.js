(function () {
  var email = 'service' + '@' + 'playplus.com.tw';
  var link = document.getElementById('email-link');
  if (link) {
    link.href = 'mailto:' + email;
    link.textContent = email;
  }
})();

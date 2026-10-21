// Switch async-loaded CSS from media="print" to media="all" after load
// Covers both .async-css (our own) and onload-based links added by generateCritical
document.querySelectorAll('link[rel="stylesheet"][media="print"]').forEach(function (link) {
  link.removeAttribute('onload');
  link.addEventListener('load', function () {
    this.media = 'all';
  });
  // If already loaded (cached), switch immediately
  if (link.sheet) {
    link.media = 'all';
  }
});

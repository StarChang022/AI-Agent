import LazyLoad from "vanilla-lazyload";

document.addEventListener("DOMContentLoaded", function() {

  new LazyLoad({
    elements_selector: ".lazyload"
  });

});
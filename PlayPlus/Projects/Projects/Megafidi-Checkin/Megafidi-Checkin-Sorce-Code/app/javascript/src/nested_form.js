// nested_form

document.addEventListener("DOMContentLoaded", function() {

  let addRemoveEvent = function(i){
    i.addEventListener('click',
      function(event){

        let _obj = event.target
        let obj = _obj.closest(".remove-object-btn")

        let obj_parent = obj.closest(obj.dataset.target)
        let destory_input = obj_parent.querySelector("input[data-name='_destroy']")
        destory_input.value = true
        obj_parent.style.setProperty("display", "none")
        event.stopPropagation()
      },
      false)
  }

  document.querySelectorAll(".build-object-btn").forEach(function(i){
    i.addEventListener('click',
      function(event){
        let obj = event.target
        let time = new Date().getTime();
        let regexp = new RegExp(obj.dataset.id, 'g')
        let form = new DOMParser().parseFromString(obj.dataset.form.replace(regexp, time), 'text/html').body.firstChild;
        let form_dom = document.querySelector(obj.dataset.target).appendChild(form)
        let remove_object_btn = form_dom.querySelector(".remove-object-btn")
        console.log(form_dom)

        addRemoveEvent(remove_object_btn)
        event.stopPropagation()
      },
      false)
  })

  document.querySelectorAll(".remove-object-btn").forEach(function(i){
    addRemoveEvent(i)
  })

})

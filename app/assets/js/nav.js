$(function() {
  $(".toggle-btn-holder button").click(function() {
    $(".submenu", $(this).parent().parent()).slideToggle();
  });
});

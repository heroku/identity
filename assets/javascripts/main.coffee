$ ->
  $('#reset_email').focus ->
    if $(this).val() == 'email address'
      $(this).val('')

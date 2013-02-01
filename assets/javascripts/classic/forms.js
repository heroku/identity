$(document).ready(function() {
  
  // -- add classes to form fields
  $('html body input[type="text"], html body input[type="password"]').addClass("text");
  $('input[type="submit"]').addClass("submit");
  // -- wrap error fields with error div
  $("form .fieldWithErrors").closest("div.field").addClass("error")
  // -- add active class to active elements
  $("form select, form .text, form textarea").focus(function( ){
    $(this).closest("div.field").addClass("active");
    $(this).closest("fieldset").addClass("active");
  });
  // -- remove active class from inactive elements
  $("form select, form .text, form textarea").blur(function( ){
    $(this).closest("div.field").removeClass("active");
    $(this).closest("fieldset").removeClass("active");
  });
  // -- make error notice the same width as error field
  $("form .fieldWithErrors input, form .fieldWithErrors textarea").each(function(i, field){
    width = $(field).width();
    $(field).closest('div.field').find('.formError').width(width);
  });

  // ********************* PASSWORD METER

  if ($('input#change_passwd').length > 0) var $button = $('input#change_passwd');

  var passwordMessaging = function(value)
  {    
    var minLength  = value.length >= 6,
        goodLength = value.length >= 8,
        hasNumeric = value.match(/\d/),
        hasAlpha   = value.match(/[a-z]/),
        hasCapital = value.match(/[A-Z]/),
        hasNonAlphaNumeric = value.match(/[^a-zA-Z0-9]/);
        
    var weak = minLength,
        good = goodLength && hasAlpha && hasNumeric,
        strong = goodLength && hasAlpha && hasNumeric && hasCapital && hasNonAlphaNumeric;

    var $hint = $('span.hint'),
        hints = {
          strong:  'Strong password',
          good:    'Good password',
          weak:    'Weak password',
          defaulty: 'minimum 6 characters letters,<br>numbers, and symbols'
        },
        passwordRating;

    $hint.removeClass('strong good weak defaulty');

    $button.removeAttr('disabled').removeClass('disabled');

    if(strong)
      passwordRating = 'strong';
    else if(good)
      passwordRating = 'good';
    else if(weak)
      passwordRating = 'weak';
    else {
      passwordRating = 'defaulty';
      $button.attr('disabled','true').addClass('disabled');
    }
    
    $hint.html(hints[passwordRating]).addClass(passwordRating);
  };

  $('#user_password').bind('keyup', function(){ passwordMessaging(this.value) });
  $('#user_password_confirmation').bind('keyup', function(){
    var password = $('#user_password').val(),
        password_confirmation = $('#user_password_confirmation').val();

    if(password && password === password_confirmation)
      passwordMessaging(this.value);
  });
  $passwordFields = $('#user_password, #user_password_confirmation');

  $passwordFields.bind('blur', function(){
    var password = $('#user_password').val(),
        password_confirmation = $('#user_password_confirmation').val();

    if(password && password_confirmation && password !== password_confirmation)
    {
      $('.new-password .hint')
        .text('Passwords do not match')
        .removeClass('weak')
        .removeClass('good')
        .removeClass('strong')
        .addClass('bad-match');
    }
  });

  $passwordFields.bind('focus', function(){
    if( $('.new-password .hint.bad-match').size() )
    {
      $('.new-password .hint').removeClass('bad-match')
     
      passwordMessaging('');
    }
  });

  if ($('#user_password').length > 0) passwordMessaging($('#user_password').val());

});

// include authenticity token in any ajax requests
$(document).ajaxSend(function(event, request, settings) {
  if (typeof(AUTH_TOKEN) == "undefined") return;
  if (settings.type == 'GET' || settings.type == 'get') return;
  settings.data = settings.data || "";
  settings.data += (settings.data ? "&" : "") + "authenticity_token=" + encodeURIComponent(AUTH_TOKEN);
  request.setRequestHeader("Content-Type", settings.contentType);
});
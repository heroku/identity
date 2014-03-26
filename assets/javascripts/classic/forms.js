$(document).ready(function() {

  // -- add classes to form fields
  $('html body input[type="text"], html body input[type="password"]').addClass("text");
  $('input[type="submit"]').addClass("submit");
  // -- wrap error fields with error div
  $("form .fieldWithErrors").closest("div.field").addClass("error")
  // -- add active class to active elements
  $("form select, form .text, form textarea").focus(function() {
    $(this).closest("div.field").addClass("active");
    $(this).closest("fieldset").addClass("active");
  });
  // -- remove active class from inactive elements
  $("form select, form .text, form textarea").blur(function() {
    $(this).closest("div.field").removeClass("active");
    $(this).closest("fieldset").removeClass("active");
  });
  // -- make error notice the same width as error field
  $("form .fieldWithErrors input, form .fieldWithErrors textarea").each(function(i, field) {
    width = $(field).width();
    $(field).closest('div.field').find('.formError').width(width);
  });

  // ********************* PASSWORD METER

  var applyPasswordMeter = function() {
    var $button = $('input#change_passwd'),
        $hint = $('span.hint'),
        $pwd = $('#user_password'),
        $pwdCon = $('#user_password_confirmation'),
        $pwdFields = $('#user_password, #user_password_confirmation');

    var passwordMessaging = function() {
      var value = $pwd.val(),
          minLength  = value.length >= 8,
          goodLength = value.length >= 12,
          hasNumeric = value.match(/\d/),
          hasAlpha   = value.match(/[a-z]/),
          hasCapital = value.match(/[A-Z]/),
          hasNonAlphaNumeric = value.match(/[^a-zA-Z0-9]/),
          weak = minLength,
          good = goodLength && hasAlpha && hasNumeric,
          strong = goodLength && hasAlpha && hasNumeric && hasCapital && hasNonAlphaNumeric,
          hints = {
            strong:  'Strong password',
            good:    'Good password',
            weak:    'Weak password',
            defaulty: 'minimum 8 characters letters,<br>numbers, and symbols'
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

    $pwd.bind('keyup', passwordMessaging);

    $pwdCon.bind('keyup', function() {
      var password = $pwd.val(),
          password_confirmation = $pwdCon.val();

      if(password && password === password_confirmation) {
        passwordMessaging();
      }
    });

    $button.bind('click', function(e) {
      var password = $pwd.val(),
          password_confirmation = $pwdCon.val();

      if(password && password_confirmation && password !== password_confirmation) {
        e.preventDefault();
        $hint
          .text('Passwords do not match')
          .removeClass('weak')
          .removeClass('good')
          .removeClass('strong')
          .addClass('bad-match');
      }
    });

    $pwdFields.bind('focus', function() {
      if ($hint.hasClass('bad-match')) {
        $hint.removeClass('bad-match');
        passwordMessaging();
      }
    });

    if ($pwd.length > 0) {
      passwordMessaging();
    }
  }

  if ($('input#change_passwd').length > 0) {
    applyPasswordMeter();
  }
});

// include authenticity token in any ajax requests
$(document).ajaxSend(function(event, request, settings) {
  if (typeof(AUTH_TOKEN) == "undefined") return;
  if (settings.type == 'GET' || settings.type == 'get') return;
  settings.data = settings.data || "";
  settings.data += (settings.data ? "&" : "") + "authenticity_token=" + encodeURIComponent(AUTH_TOKEN);
  request.setRequestHeader("Content-Type", settings.contentType);
});

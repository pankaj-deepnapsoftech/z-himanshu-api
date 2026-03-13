CLASS zcl_register_handler DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_service_extension.

  PRIVATE SECTION.
    METHODS handle_post
      IMPORTING
        request  TYPE REF TO if_web_http_request
        response TYPE REF TO if_web_http_response.

ENDCLASS.

CLASS zcl_register_handler IMPLEMENTATION.

  METHOD if_http_service_extension~handle_request.
    CASE request->get_method( ).
      WHEN 'POST'.
        handle_post( request = request response = response ).
      WHEN OTHERS.
        response->set_status( i_code = 405 i_reason = 'Method Not Allowed' ).
    ENDCASE.
  ENDMETHOD.

  METHOD handle_post.
    DATA: lv_body    TYPE string,
          ls_request TYPE zdemo_users,
          ls_success TYPE abap_bool,
          lv_message TYPE string.

    " 1. Request body padhlo
    lv_body = request->get_text( ).

    " 2. JSON deserialize karo
    /ui2/cl_json=>deserialize(
      EXPORTING json = lv_body
      CHANGING  data = ls_request ).

    " 3. Validation - koi field khaali nahi hona chahiye
    IF ls_request-name IS INITIAL OR
       ls_request-username IS INITIAL OR
       ls_request-email IS INITIAL OR
       ls_request-password IS INITIAL.

      lv_message = '{"success":false,"message":"All fields are required"}'.
      response->set_status( i_code = 400 i_reason = 'Bad Request' ).

    ELSE.
      " 4. Check karo - username pehle se exist toh nahi karta?
      SELECT SINGLE username FROM zdemo_users
        WHERE username = @ls_request-username
        INTO @DATA(lv_existing).

      IF sy-subrc = 0.
        lv_message = '{"success":false,"message":"Username already exists"}'.
        response->set_status( i_code = 409 i_reason = 'Conflict' ).

      ELSE.
        " 5. Table mein save karo
        INSERT zdemo_users FROM @( VALUE zdemo_users(
          mandt    = sy-mandt
          username = ls_request-username
          name     = ls_request-name
          email    = ls_request-email
          password = ls_request-password
        ) ).

        IF sy-subrc = 0.
          COMMIT WORK.
          lv_message = '{"success":true,"message":"User registered successfully"}'.
          response->set_status( i_code = 201 i_reason = 'Created' ).
        ELSE.
          lv_message = '{"success":false,"message":"Database error"}'.
          response->set_status( i_code = 500 i_reason = 'Internal Server Error' ).
        ENDIF.
      ENDIF.
    ENDIF.

    " 6. Response bhejo
    response->set_text( lv_message ).
    response->set_header_field(
      i_name  = 'Content-Type'
      i_value = 'application/json' ).

  ENDMETHOD.

ENDCLASS.

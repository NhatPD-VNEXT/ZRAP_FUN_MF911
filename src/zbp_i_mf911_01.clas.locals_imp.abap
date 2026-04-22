CLASS lhc_header DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PUBLIC SECTION.
    CONSTANTS: gcf_status_normal TYPE c LENGTH 3 VALUE '正常',
               gcf_status_error  TYPE c LENGTH 3 VALUE 'エラー'.

    CONSTANTS gcf_label_info TYPE string VALUE 'ZC_MF911_02'.

    CLASS-DATA: gcf_csv_delimiter  TYPE c VALUE ',',
                gcf_numb_delimiter TYPE c VALUE ',',
                gcf_date_delimiter TYPE c VALUE '/'.

  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR header RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR header RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR header RESULT result.

    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE header.

    METHODS getDataFile FOR DETERMINE ON MODIFY
      IMPORTING keys FOR header~getDataFile.

    METHODS updateBusinessObject FOR DETERMINE ON SAVE
      IMPORTING keys FOR header~updateBusinessObject.

    METHODS vldBeforeSave FOR VALIDATE ON SAVE
      IMPORTING keys FOR header~vldBeforeSave.

ENDCLASS.

CLASS lhc_header IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zi_mf911_01 IN LOCAL MODE
        ENTITY header ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_headers) FAILED DATA(ls_failed).
    result = VALUE #( FOR ls IN lt_headers (
        %tky                    = ls-%tky
        %features-%action-edit  = if_abap_behv=>fc-o-disabled
    ) ).
  ENDMETHOD.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD precheck_delete.
    DATA: lds_reported LIKE LINE OF reported-header.
    LOOP AT keys INTO DATA(ls_key).
      IF ls_key-%is_draft = '00'.
        CLEAR lds_reported.
        lds_reported-%tky = ls_key-%tky.
        lds_reported-%msg = new_message( id       = 'ZRAP_COM_99'
                                         number   = '003'
                                         severity = if_abap_behv_message=>severity-error ).
        APPEND lds_reported TO reported-header.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-header.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD getDataFile.
    " Step 1: Read header entities to get attachment data
    READ ENTITIES OF zi_mf911_01 IN LOCAL MODE
      ENTITY header
        FIELDS ( AttachmentUUID Attachment Mimetype FileName )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers)
      FAILED DATA(ls_failed).

    LOOP AT lt_headers INTO DATA(ls_header).
      " Step 2: Parse CSV file content into file data table
      " Use zcl_mf911_01=>gtt_file_data to define the typed structure
      DATA(lt_file_data) = VALUE zcl_mf911_01=>gtt_file_data( ).
      " TODO: Implement CSV parsing logic
      "   cl_bcs_convert=>string_to_tab( ... ) or custom split logic

      " Step 3: Delete existing item entities (only if draft)
      IF ls_header-%is_draft = if_abap_behv=>mk-on.
        READ ENTITIES OF zi_mf911_01 IN LOCAL MODE
          ENTITY header BY \_item
            FIELDS ( ItemUUID )
            WITH VALUE #( ( %tky = ls_header-%tky ) )
          RESULT DATA(lt_existing_items).

        IF lt_existing_items IS NOT INITIAL.
          MODIFY ENTITIES OF zi_mf911_01 IN LOCAL MODE
            ENTITY item
              DELETE FROM CORRESPONDING #( lt_existing_items )
            REPORTED DATA(ls_del_reported)
            FAILED DATA(ls_del_failed)
            MAPPED DATA(ls_del_mapped).
        ENDIF.
      ENDIF.

      " Step 4: Convert file data to item create structures
      DATA(lt_item_create) = VALUE zbp_i_mf911_01=>tt_item_create( ).
      LOOP AT lt_file_data INTO DATA(ls_file_line).
        APPEND VALUE #(
          %cid              = |ITEM_{ sy-tabix }|
          %is_draft         = if_abap_behv=>mk-on
          AttachmentUUID    = ls_header-AttachmentUUID
          PoGroup           = zcl_mf911_01=>convert_data_file( ls_file_line )-PoGroup
          PurchaseOrderItem = zcl_mf911_01=>convert_data_file( ls_file_line )-PurchaseOrderItem
          " TODO: map all fields
        ) TO lt_item_create.
      ENDLOOP.

      " Step 5: Create item entities via composition
      IF lt_item_create IS NOT INITIAL.
        MODIFY ENTITIES OF zi_mf911_01 IN LOCAL MODE
          ENTITY header
            CREATE BY \_item
            FIELDS ( PoGroup PurchaseOrderItem PurchaseDocumentType
                     CompanyCode PurchasingOrganization PurchasingGroup
                     Supplier Material Plant
                     OrderQuantity PurchaseOrderQuantityUnit
                     NetPriceAmount DocumentCurrency )
            WITH VALUE #( (
              %tky        = ls_header-%tky
              %target     = lt_item_create
            ) )
          REPORTED DATA(ls_crt_reported)
          FAILED DATA(ls_crt_failed)
          MAPPED DATA(ls_crt_mapped).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD updateBusinessObject.
    " Step 1: Read headers
    READ ENTITIES OF zi_mf911_01 IN LOCAL MODE
      ENTITY header
        FIELDS ( AttachmentUUID TotalCount SuccessCount WarningCount ErrorCount )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_headers)
      FAILED DATA(ls_failed).

    LOOP AT lt_headers INTO DATA(ls_header).
      " Step 2: Read items for this header
      READ ENTITIES OF zi_mf911_01 IN LOCAL MODE
        ENTITY header BY \_item
          ALL FIELDS
          WITH VALUE #( ( %tky = ls_header-%tky ) )
        RESULT DATA(lt_items).

      " Step 3: Group items by Group field and dispatch parallel BOI calls
      DATA(lt_groups) = VALUE string_table( ).
      LOOP AT lt_items INTO DATA(ls_item).
        COLLECT ls_item-PoGroup INTO lt_groups.
      ENDLOOP.

      DATA(lv_success) = 0.
      DATA(lv_error)   = 0.

      LOOP AT lt_groups INTO DATA(lv_group).
        DATA(lt_group_items) = VALUE zcl_mf911_01=>gtt_data(
          FOR ls IN lt_items WHERE ( PoGroup = lv_group )
            ( cid      = |CID_{ sy-tabix }|
              po_group = ls-PoGroup
              " TODO: populate item sub-table from ls fields
            ) ).

        DATA(lo_zcl) = NEW zcl_mf911_01( ).
        DATA(ls_input) = VALUE zcl_mf911_01=>gts_parallel_input(
          data = lt_group_items[ 1 ] ).
        DATA ls_output TYPE zcl_mf911_01=>gts_parallel_output.
        lo_zcl->execute_parallel(
          EXPORTING is_input  = ls_input
          IMPORTING es_output = ls_output ).

        " TODO: process ls_output — update item status/message/criticality,
        "        increment lv_success / lv_error counters
      ENDLOOP.

      " Step 4: Update header counts
      MODIFY ENTITIES OF zi_mf911_01 IN LOCAL MODE
        ENTITY header
          UPDATE FIELDS ( TotalCount SuccessCount WarningCount ErrorCount )
          WITH VALUE #( (
            %tky         = ls_header-%tky
            TotalCount   = lines( lt_items )
            SuccessCount = lv_success
            WarningCount = 0
            ErrorCount   = lv_error
          ) )
        REPORTED DATA(ls_upd_reported)
        FAILED DATA(ls_upd_failed)
        MAPPED DATA(ls_upd_mapped).
    ENDLOOP.
  ENDMETHOD.

  METHOD vldBeforeSave.
    READ ENTITIES OF zi_mf911_01 IN LOCAL MODE
      ENTITY header BY \_item
        FIELDS ( ItemUUID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_items).

    IF lt_items IS INITIAL.
      APPEND VALUE #( %tky = keys[ 1 ]-%tky ) TO failed-header.
      APPEND VALUE #( %tky = keys[ 1 ]-%tky
                      %msg = new_message( id       = 'ZRAP_COM_99'
                                          number   = '004'
                                          severity = if_abap_behv_message=>severity-error )
                    ) TO reported-header.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

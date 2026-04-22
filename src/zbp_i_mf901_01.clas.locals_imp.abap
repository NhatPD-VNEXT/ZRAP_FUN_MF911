CLASS lhc_header DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PUBLIC SECTION.
    CONSTANTS: gcf_status_normal TYPE c LENGTH 3 VALUE '正常',
               gcf_status_error  TYPE c LENGTH 3 VALUE 'エラー',
               gcf_label_info    TYPE string VALUE 'ZC_MF901_02'.

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
    READ ENTITIES OF zi_mf901_01 IN LOCAL MODE
        ENTITY header ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_headers) FAILED DATA(ls_failed).
    result = VALUE #( FOR ls IN lt_headers (
        %tky = ls-%tky
        %features-%action-edit = if_abap_behv=>fc-o-disabled
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
    DATA: lt_headers     TYPE TABLE FOR READ RESULT zi_mf901_01\\header,
          lt_items       TYPE TABLE FOR CREATE zi_mf901_01\\item,
          lt_del         TYPE TABLE FOR DELETE zi_mf901_01\\item,
          lt_existing    TYPE TABLE FOR READ RESULT zi_mf901_01\\item.

    READ ENTITIES OF zi_mf901_01 IN LOCAL MODE
      ENTITY header
        FIELDS ( Attachment Mimetype FileName )
        WITH CORRESPONDING #( keys )
      RESULT lt_headers.

    LOOP AT lt_headers INTO DATA(ls_header).
      DATA lt_file_data TYPE zcl_mf901_01=>gtt_file_data.

      " TODO: decode ls_header-Attachment (base64/xstring) → split by line
      " → SPLIT each line BY gcf_csv_delimiter → fill lt_file_data rows

      " Delete existing items (guard: only when items exist)
      READ ENTITIES OF zi_mf901_01 IN LOCAL MODE
        ENTITY header BY \_item FIELDS ( ItemUUID )
        WITH VALUE #( ( %tky = ls_header-%tky ) )
        RESULT lt_existing.

      IF lt_existing IS NOT INITIAL.
        lt_del = CORRESPONDING #( lt_existing MAPPING %tky = %tky ).
        MODIFY ENTITIES OF zi_mf901_01 IN LOCAL MODE
          ENTITY item DELETE FROM lt_del
          REPORTED DATA(ls_rep_del)
          FAILED   DATA(ls_fail_del)
          MAPPED   DATA(ls_map_del).
      ENDIF.

      " Create new items from CSV rows
      IF lt_file_data IS NOT INITIAL.
        DATA(lv_cid_ref) = |{ ls_header-%tky-%key-AttachmentUUID }|.
        LOOP AT lt_file_data INTO DATA(ls_line).
          DATA(ls_item) = zcl_mf901_01=>convert_data_file( ls_line ).
          APPEND VALUE #(
            %cid_ref = lv_cid_ref
            %target  = VALUE #( (
              %cid              = |ITEM_{ sy-tabix }|
              Group             = ls_item-group
              PurchaseOrderItem = ls_item-purchaseorderitem
              PurchaseDocumentType = ls_item-purchasedocumenttype
              CompanyCode       = ls_item-companycode
              PurchasingOrganization = ls_item-purchasingorganization
              PurchasingGroup   = ls_item-purchasinggroup
              Supplier          = ls_item-supplier
              Material          = ls_item-material
              Plant             = ls_item-plant
              OrderQuantity     = ls_item-orderquantity
              NetPriceAmount    = ls_item-netpriceamount
            ) )
          ) TO lt_items.
        ENDLOOP.
      ENDIF.
    ENDLOOP.

    IF lt_items IS NOT INITIAL.
      MODIFY ENTITIES OF zi_mf901_01 IN LOCAL MODE
        ENTITY header CREATE BY \_item
          FROM lt_items
        REPORTED DATA(ls_reported)
        FAILED   DATA(ls_failed)
        MAPPED   DATA(ls_mapped).
    ENDIF.
  ENDMETHOD.

  METHOD updateBusinessObject.
    DATA: lt_headers    TYPE TABLE FOR READ RESULT zi_mf901_01\\header,
          lt_upd_header TYPE TABLE FOR UPDATE zi_mf901_01\\header,
          lt_upd_item   TYPE TABLE FOR UPDATE zi_mf901_01\\item.

    READ ENTITIES OF zi_mf901_01 IN LOCAL MODE
      ENTITY header
        FIELDS ( AttachmentUUID )
        WITH CORRESPONDING #( keys )
      RESULT lt_headers.

    LOOP AT lt_headers INTO DATA(ls_header).
      READ ENTITIES OF zi_mf901_01 IN LOCAL MODE
        ENTITY header BY \_item
          FIELDS ( ItemUUID Group PurchaseOrderItem PurchaseDocumentType
                   CompanyCode PurchasingOrganization PurchasingGroup
                   Supplier Material Plant OrderQuantity NetPriceAmount )
          WITH VALUE #( ( %tky = ls_header-%tky ) )
        RESULT DATA(lt_items).

      " Collect distinct Group values
      DATA lt_groups TYPE SORTED TABLE OF zi_mf901_02-group
        WITH UNIQUE KEY table_line.
      LOOP AT lt_items INTO DATA(ls_it).
        INSERT ls_it-Group INTO TABLE lt_groups.
      ENDLOOP.

      DATA: lv_success TYPE i VALUE 0,
            lv_warning TYPE i VALUE 0,
            lv_error   TYPE i VALUE 0.

      LOOP AT lt_groups INTO DATA(lv_group).
        DATA(lo_parallel) = NEW zcl_mf901_01( ).

        " Build item sub-table for this group
        DATA lt_group_items TYPE zcl_mf901_01=>gtt_item.
        LOOP AT lt_items INTO DATA(ls_grp_item) WHERE Group = lv_group.
          APPEND VALUE zcl_mf901_01=>gts_item_line(
            purchase_order_item    = ls_grp_item-PurchaseOrderItem
            purchase_document_type = ls_grp_item-PurchaseDocumentType
            company_code           = ls_grp_item-CompanyCode
            purchasing_org         = ls_grp_item-PurchasingOrganization
            purchasing_group       = ls_grp_item-PurchasingGroup
            supplier               = ls_grp_item-Supplier
            material               = ls_grp_item-Material
            plant                  = ls_grp_item-Plant
            order_quantity         = ls_grp_item-OrderQuantity
            net_price_amount       = ls_grp_item-NetPriceAmount
          ) TO lt_group_items.
        ENDLOOP.

        DATA(ls_input) = VALUE zcl_mf901_01=>gts_parallel_input(
          data = VALUE zcl_mf901_01=>gts_data(
            cid   = |GROUP_{ lv_group }|
            group = lv_group
            items = lt_group_items
          )
        ).
        DATA(ls_result) = lo_parallel->execute_parallel( ls_input ).

        " Update item result fields and tally counts
        LOOP AT ls_result-data INTO DATA(ls_res).
          APPEND VALUE #(
            %tky        = ls_res-%tky
            Status      = ls_res-status
            Message     = ls_res-message
            Criticality = ls_res-criticality
            %control    = VALUE #(
              Status      = if_abap_behv=>mk-on
              Message     = if_abap_behv=>mk-on
              Criticality = if_abap_behv=>mk-on )
          ) TO lt_upd_item.

          CASE ls_res-criticality
            WHEN zcl_mf901_01=>gcf_criticality_error.
              lv_error += 1.
            WHEN zcl_mf901_01=>gcf_criticality_warning.
              lv_warning += 1.
            WHEN OTHERS.
              lv_success += 1.
          ENDCASE.
        ENDLOOP.
        CLEAR lt_group_items.
      ENDLOOP.

      APPEND VALUE #(
        %tky         = ls_header-%tky
        TotalCount   = lines( lt_items )
        SuccessCount = lv_success
        WarningCount = lv_warning
        ErrorCount   = lv_error
        %control     = VALUE #(
          TotalCount   = if_abap_behv=>mk-on
          SuccessCount = if_abap_behv=>mk-on
          WarningCount = if_abap_behv=>mk-on
          ErrorCount   = if_abap_behv=>mk-on )
      ) TO lt_upd_header.
    ENDLOOP.

    IF lt_upd_item IS NOT INITIAL.
      MODIFY ENTITIES OF zi_mf901_01 IN LOCAL MODE
        ENTITY item UPDATE FROM lt_upd_item
        REPORTED DATA(ls_rep1) FAILED DATA(ls_fail1) MAPPED DATA(ls_map1).
    ENDIF.
    IF lt_upd_header IS NOT INITIAL.
      MODIFY ENTITIES OF zi_mf901_01 IN LOCAL MODE
        ENTITY header UPDATE FROM lt_upd_header
        REPORTED DATA(ls_rep2) FAILED DATA(ls_fail2) MAPPED DATA(ls_map2).
    ENDIF.
  ENDMETHOD.

  METHOD vldBeforeSave.
    READ ENTITIES OF zi_mf901_01 IN LOCAL MODE
      ENTITY header BY \_item FIELDS ( ItemUUID )
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

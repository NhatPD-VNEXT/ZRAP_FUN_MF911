************************************************************************
*  [変更履歴]                                                          *
*   バージョン情報 ：V1.00  2026/04/22  Author            TransportNr  *
*   変更内容       ：新規作成                                          *
*----------------------------------------------------------------------*
*   バージョン情報 ：V9.99  YYYY/MM/DD  変更者             移送番号    *
*   変更内容       ：                                                  *
************************************************************************
CLASS zcl_mf901_01 DEFINITION
  PUBLIC
  INHERITING FROM cl_abap_parallel
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " ★ CSV file layout — field order must match CSV column order exactly ★
    TYPES: BEGIN OF gts_file_line,
             group                  TYPE zi_mf901_02-group,
             purchase_order_item    TYPE zi_mf901_02-purchaseorderitem,
             purchase_document_type TYPE zi_mf901_02-purchasedocumenttype,
             company_code           TYPE zi_mf901_02-companycode,
             purchasing_org         TYPE zi_mf901_02-purchasingorganization,
             purchasing_group       TYPE zi_mf901_02-purchasinggroup,
             supplier               TYPE zi_mf901_02-supplier,
             material               TYPE zi_mf901_02-material,
             plant                  TYPE zi_mf901_02-plant,
             order_quantity         TYPE zi_mf901_02-orderquantity,
             net_price_amount       TYPE zi_mf901_02-netpriceamount,
           END OF gts_file_line,
           gtt_file_data TYPE STANDARD TABLE OF gts_file_line WITH EMPTY KEY.

    " ★ Item sub-table for one parallel execution unit (one group = one PO) ★
    TYPES: BEGIN OF gts_item_line,
             purchase_order_item    TYPE zi_mf901_02-purchaseorderitem,
             purchase_document_type TYPE zi_mf901_02-purchasedocumenttype,
             company_code           TYPE zi_mf901_02-companycode,
             purchasing_org         TYPE zi_mf901_02-purchasingorganization,
             purchasing_group       TYPE zi_mf901_02-purchasinggroup,
             supplier               TYPE zi_mf901_02-supplier,
             material               TYPE zi_mf901_02-material,
             plant                  TYPE zi_mf901_02-plant,
             order_quantity         TYPE zi_mf901_02-orderquantity,
             net_price_amount       TYPE zi_mf901_02-netpriceamount,
           END OF gts_item_line,
           gtt_item TYPE STANDARD TABLE OF gts_item_line WITH EMPTY KEY.

    " ★ Result item (one row per original CSV line in the group) ★
    TYPES: BEGIN OF gts_result_item,
             %tky        TYPE REF TO data,
             status      TYPE zi_mf901_02-status,
             message     TYPE zi_mf901_02-message,
             criticality TYPE zi_mf901_02-criticality,
           END OF gts_result_item,
           gtt_result_items TYPE STANDARD TABLE OF gts_result_item WITH EMPTY KEY.

    " ★ Processing data (one instance per Group value) ★
    TYPES: BEGIN OF gts_data,
             cid   TYPE abp_behv_cid,
             group TYPE zi_mf901_02-group,
             items TYPE gtt_item,
           END OF gts_data,
           gtt_data TYPE STANDARD TABLE OF gts_data WITH EMPTY KEY.

    " ★ Parallel framework wrappers ★
    TYPES: BEGIN OF gts_parallel_input,
             data TYPE gts_data,
           END OF gts_parallel_input.
    TYPES: BEGIN OF gts_parallel_output,
             data TYPE gtt_result_items,
           END OF gts_parallel_output.

    " Criticality constants (matches @UI.criticality semantics)
    CONSTANTS: gcf_criticality_error   TYPE i VALUE 1,
               gcf_criticality_warning TYPE i VALUE 2,
               gcf_criticality_success TYPE i VALUE 3.

    " Convert one CSV file row → item CDS structure for CREATE BY \_item
    CLASS-METHODS convert_data_file
      IMPORTING is_data                 TYPE gts_file_line
      RETURNING VALUE(rs_import_detail) TYPE zi_mf901_02.

    " Required override — cl_abap_parallel dispatches to this per work unit
    METHODS do REDEFINITION.

    " Entry point called from updateBusinessObject per Group
    METHODS execute_parallel
      IMPORTING is_input        TYPE gts_parallel_input
      RETURNING VALUE(rs_ouput) TYPE gts_parallel_output.

    " BOI call: MODIFY ENTITIES OF I_PurchaseOrderTP_2 + COMMIT ENTITIES
    METHODS main_process
      IMPORTING is_input        TYPE gts_parallel_input
      RETURNING VALUE(rs_ouput) TYPE gts_parallel_output.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_mf901_01 IMPLEMENTATION.

  METHOD convert_data_file.
    rs_import_detail-group                  = is_data-group.
    rs_import_detail-purchaseorderitem      = is_data-purchase_order_item.
    rs_import_detail-purchasedocumenttype   = is_data-purchase_document_type.
    rs_import_detail-companycode            = is_data-company_code.
    rs_import_detail-purchasingorganization = is_data-purchasing_org.
    rs_import_detail-purchasinggroup        = is_data-purchasing_group.
    rs_import_detail-supplier               = is_data-supplier.
    rs_import_detail-material               = is_data-material.
    rs_import_detail-plant                  = is_data-plant.
    rs_import_detail-orderquantity          = is_data-order_quantity.
    rs_import_detail-netpriceamount         = is_data-net_price_amount.
  ENDMETHOD.

  METHOD do.
    " TODO: deserialize cl_abap_parallel input object → gts_parallel_input,
    "        call main_process, serialize gts_parallel_output back to output object.
    " Pattern:
    "   DATA(ls_input) = CAST gts_parallel_input( input ).
    "   DATA(ls_output) = main_process( ls_input ).
    "   output = ls_output.
  ENDMETHOD.

  METHOD execute_parallel.
    " Direct call (non-parallel fallback) — replace with cl_abap_parallel dispatch if needed
    rs_ouput = main_process( is_input ).
  ENDMETHOD.

  METHOD main_process.
    DATA lv_cid TYPE abp_behv_cid.
    lv_cid = is_input-data-cid.

    " All items in the group share the same PO header fields (taken from first item)
    DATA(ls_first) = is_input-data-items[ 1 ].

    MODIFY ENTITIES OF i_purchaseordertp_2
      ENTITY PurchaseOrder
        CREATE FIELDS (
          PurchaseOrderType
          CompanyCode
          PurchasingOrganization
          PurchasingGroup
          Supplier
        )
        WITH VALUE #( (
          %cid                   = lv_cid
          PurchaseOrderType      = ls_first-purchase_document_type
          CompanyCode            = ls_first-company_code
          PurchasingOrganization = ls_first-purchasing_org
          PurchasingGroup        = ls_first-purchasing_group
          Supplier               = ls_first-supplier
        ) )

      ENTITY PurchaseOrder
        CREATE BY \_PurchaseOrderItem
          FIELDS (
            Material
            Plant
            OrderQuantity
            NetPriceAmount
          )
          WITH VALUE #(
            ( %cid_ref = lv_cid
              %target  = VALUE #(
                FOR lv_item IN is_input-data-items
                INDEX INTO lv_idx (
                  %cid           = |{ lv_cid }_ITEM_{ lv_idx }|
                  Material       = lv_item-material
                  Plant          = lv_item-plant
                  OrderQuantity  = lv_item-order_quantity
                  NetPriceAmount = lv_item-net_price_amount
                )
              )
            )
          )

      REPORTED DATA(ls_mod_reported)
      FAILED   DATA(ls_mod_failed)
      MAPPED   DATA(ls_mod_mapped).

    COMMIT ENTITIES
      BEGIN
        RESPONSE OF i_purchaseordertp_2
          FAILED   DATA(ls_com_failed)
          REPORTED DATA(ls_com_reported)
      END.

    " Build result: one entry per item in the group
    DATA lv_idx2 TYPE i VALUE 1.
    LOOP AT is_input-data-items INTO DATA(ls_item_out).
      IF ls_com_failed IS INITIAL AND ls_mod_failed IS INITIAL.
        APPEND VALUE gts_result_item(
          status      = gcf_status_ok( )
          criticality = gcf_criticality_success
        ) TO rs_ouput-data.
      ELSE.
        " Collect first error message for this item
        DATA lv_msg TYPE string.
        READ TABLE ls_com_reported INDEX 1 INTO DATA(ls_com_rep_line).
        IF sy-subrc = 0.
          lv_msg = ls_com_rep_line-%msg->if_message~get_text( ).
        ENDIF.
        APPEND VALUE gts_result_item(
          status      = gcf_status_error( )
          message     = lv_msg
          criticality = gcf_criticality_error
        ) TO rs_ouput-data.
      ENDIF.
      lv_idx2 += 1.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

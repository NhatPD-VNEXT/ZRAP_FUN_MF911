************************************************************************
*  [変更履歴]                                                          *
*   バージョン情報 ：V1.00  YYYY/MM/DD  Author            TransportNr  *
*   変更内容       ：新規作成                                          *
*----------------------------------------------------------------------*
*   バージョン情報 ：V9.99  YYYY/MM/DD  変更者             移送番号    *
*   変更内容       ：新規作成                                          *
************************************************************************
CLASS zcl_mf911_01 DEFINITION
  PUBLIC
  INHERITING FROM cl_abap_parallel
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " ★ CSV file layout — field order must match CSV column order exactly ★
    TYPES: BEGIN OF gts_file_line,
             po_group               TYPE zi_mf911_02-pogroup,
             purchase_order_item    TYPE zi_mf911_02-purchaseorderitem,
             purchase_document_type TYPE zi_mf911_02-purchasedocumenttype,
             company_code           TYPE zi_mf911_02-companycode,
             purchasing_org         TYPE zi_mf911_02-purchasingorganization,
             purchasing_group       TYPE zi_mf911_02-purchasinggroup,
             supplier               TYPE zi_mf911_02-supplier,
             material               TYPE zi_mf911_02-material,
             plant                  TYPE zi_mf911_02-plant,
             order_quantity                TYPE zi_mf911_02-orderquantity,
             purchase_order_quantity_unit  TYPE zi_mf911_02-purchaseorderquantityunit,
             net_price_amount              TYPE zi_mf911_02-netpriceamount,
             document_currency             TYPE zi_mf911_02-documentcurrency,
           END OF gts_file_line,
           gtt_file_data TYPE STANDARD TABLE OF gts_file_line WITH EMPTY KEY.

    " ★ Item sub-type for processing ★
    TYPES: BEGIN OF gts_item_line,
             po_group               TYPE zi_mf911_02-pogroup,
             purchase_order_item    TYPE zi_mf911_02-purchaseorderitem,
             purchase_document_type TYPE zi_mf911_02-purchasedocumenttype,
             company_code           TYPE zi_mf911_02-companycode,
             purchasing_org         TYPE zi_mf911_02-purchasingorganization,
             purchasing_group       TYPE zi_mf911_02-purchasinggroup,
             supplier               TYPE zi_mf911_02-supplier,
             material               TYPE zi_mf911_02-material,
             plant                  TYPE zi_mf911_02-plant,
             order_quantity                TYPE zi_mf911_02-orderquantity,
             purchase_order_quantity_unit  TYPE zi_mf911_02-purchaseorderquantityunit,
             net_price_amount              TYPE zi_mf911_02-netpriceamount,
             document_currency             TYPE zi_mf911_02-documentcurrency,
             item_uuid                     TYPE zi_mf911_02-itemuuid,
           END OF gts_item_line,
           gtt_item_data TYPE STANDARD TABLE OF gts_item_line WITH EMPTY KEY.

    " ★ Processing data (one row per parallel execution unit = one PO group) ★
    TYPES: BEGIN OF gts_data,
             cid         TYPE abp_behv_cid,
             po_group    TYPE zi_mf911_02-pogroup,
             items       TYPE gtt_item_data,
             status      TYPE zi_mf911_02-status,
             message     TYPE zi_mf911_02-message,
             criticality TYPE zi_mf911_02-criticality,
           END OF gts_data,
           gtt_data TYPE STANDARD TABLE OF gts_data WITH EMPTY KEY.

    " ★ Parallel wrappers ★
    TYPES: BEGIN OF gts_parallel_input,
             data TYPE gts_data,
           END OF gts_parallel_input.
    TYPES: BEGIN OF gts_parallel_output,
             data TYPE TABLE OF gts_data WITH DEFAULT KEY,
           END OF gts_parallel_output.

    " Criticality value constants
    CONSTANTS: gcf_criticality_error   TYPE i VALUE 1,
               gcf_criticality_warning TYPE i VALUE 2,
               gcf_criticality_success TYPE i VALUE 3.

    " Convert raw CSV row → item CDS structure
    CLASS-METHODS convert_data_file
      IMPORTING is_data                 TYPE gts_file_line
      RETURNING VALUE(rs_import_detail) TYPE zi_mf911_02.

    " Required by cl_abap_parallel — runs one unit
    METHODS do REDEFINITION.

    " Trigger parallel execution for one group
    METHODS execute_parallel
      IMPORTING is_input   TYPE gts_parallel_input
      EXPORTING es_output  TYPE gts_parallel_output.

    " Core BOI logic — MODIFY ENTITIES OF I_PurchaseOrderTP_2 + COMMIT ENTITIES
    METHODS main_process
      IMPORTING is_input        TYPE gts_parallel_input
      RETURNING VALUE(rs_ouput) TYPE gts_parallel_output.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_mf911_01 IMPLEMENTATION.

  METHOD convert_data_file.
    rs_import_detail-pogroup                = is_data-po_group.
    rs_import_detail-purchaseorderitem      = is_data-purchase_order_item.
    rs_import_detail-purchasedocumenttype   = is_data-purchase_document_type.
    rs_import_detail-companycode            = is_data-company_code.
    rs_import_detail-purchasingorganization = is_data-purchasing_org.
    rs_import_detail-purchasinggroup        = is_data-purchasing_group.
    rs_import_detail-supplier               = is_data-supplier.
    rs_import_detail-material               = is_data-material.
    rs_import_detail-plant                  = is_data-plant.
    rs_import_detail-orderquantity               = is_data-order_quantity.
    rs_import_detail-purchaseorderquantityunit   = is_data-purchase_order_quantity_unit.
    rs_import_detail-netpriceamount              = is_data-net_price_amount.
    rs_import_detail-documentcurrency            = is_data-document_currency.
  ENDMETHOD.

  METHOD do.
    DATA: ls_input  TYPE gts_parallel_input,
          ls_output TYPE gts_parallel_output.

    IMPORT param_input = ls_input FROM DATA BUFFER p_in.

    ls_output = main_process( ls_input ).

    EXPORT param_output = ls_output TO DATA BUFFER p_out.
  ENDMETHOD.

  METHOD execute_parallel.
    DATA: ldf_xinput  TYPE LINE OF cl_abap_parallel=>t_in_tab,
          ldt_xinput  TYPE cl_abap_parallel=>t_in_tab,
          ldt_xoutput TYPE cl_abap_parallel=>t_out_tab,
          lds_xoutput TYPE LINE OF cl_abap_parallel=>t_out_tab.

    EXPORT param_input = is_input TO DATA BUFFER ldf_xinput.
    APPEND ldf_xinput TO ldt_xinput.

    run( EXPORTING p_in_tab  = ldt_xinput
         IMPORTING p_out_tab = ldt_xoutput ).

    IF ldt_xoutput IS NOT INITIAL.
      lds_xoutput = ldt_xoutput[ 1 ].
      TRY.
          IMPORT param_output = es_output FROM DATA BUFFER lds_xoutput-result.
        CATCH cx_root INTO FINAL(lo_error).
          ASSERT 1 = 0.
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD main_process.
    DATA: ls_result TYPE gts_data.
    ls_result = is_input-data.

    " Build create structures for I_PurchaseOrderTP_2
    DATA(lv_cid_po) = |PO_{ is_input-data-cid }|.

    MODIFY ENTITIES OF I_PurchaseOrderTP_2
      ENTITY PurchaseOrder
        CREATE FIELDS ( PurchaseOrderType
                        CompanyCode
                        PurchasingOrganization
                        PurchasingGroup
                        Supplier )
        WITH VALUE #( (
          %cid                   = lv_cid_po
          PurchaseOrderType      = is_input-data-items[ 1 ]-purchase_document_type
          CompanyCode            = is_input-data-items[ 1 ]-company_code
          PurchasingOrganization = is_input-data-items[ 1 ]-purchasing_org
          PurchasingGroup        = is_input-data-items[ 1 ]-purchasing_group
          Supplier               = is_input-data-items[ 1 ]-supplier
        ) )
      ENTITY PurchaseOrderItem
        CREATE BY \_PurchaseOrderItem
        FIELDS ( PurchaseOrderItem
                 AccountAssignmentCategory
                 Material
                 Plant
                 OrderQuantity
                 PurchaseOrderQuantityUnit
                 NetPriceAmount
                 DocumentCurrency )
        WITH VALUE #(
          FOR idx = 1 THEN idx + 1 WHILE idx <= lines( is_input-data-items )
          LET ls_it = is_input-data-items[ idx ] IN (
            %cid_ref                   = lv_cid_po
            %cid                       = |ITEM_{ lv_cid_po }_{ idx }|
            PurchaseOrderItem          = ls_it-purchase_order_item
            Material                   = ls_it-material
            Plant                      = ls_it-plant
            OrderQuantity              = ls_it-order_quantity
            PurchaseOrderQuantityUnit  = ls_it-purchase_order_quantity_unit
            NetPriceAmount             = ls_it-net_price_amount
            DocumentCurrency           = ls_it-document_currency
          ) )
      REPORTED DATA(ls_reported)
      FAILED   DATA(ls_failed)
      MAPPED   DATA(ls_mapped).

    COMMIT ENTITIES BEGIN
      RESPONSE OF I_PurchaseOrderTP_2
      FAILED   DATA(ls_commit_failed)
      REPORTED DATA(ls_commit_reported).
    COMMIT ENTITIES END.

    IF ls_commit_failed IS INITIAL AND ls_failed IS INITIAL.
      ls_result-status      = 'OK'.
      ls_result-criticality = gcf_criticality_success.
      ls_result-message     = 'PO created successfully'.
    ELSE.
      ls_result-status      = 'ERR'.
      ls_result-criticality = gcf_criticality_error.
      " TODO: extract message text from ls_commit_reported
      ls_result-message     = 'Error during PO creation'.
    ENDIF.

    rs_ouput-data = VALUE #( ( ls_result ) ).
  ENDMETHOD.

ENDCLASS.

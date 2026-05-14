CLASS zdmo_gen_rap110_single_kar DEFINITION
  INHERITING FROM zdmo_cl_rap_generator_base
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
    METHODS constructor
      IMPORTING i_unique_suffix TYPE string OPTIONAL.

  PROTECTED SECTION.

  PRIVATE SECTION.

    CONSTANTS:
      co_prefix             TYPE string       VALUE 'ZRAP110_',
      co_zlocal_package     TYPE sxco_package VALUE 'ZLOCAL',
      co_zrap110_ex_package TYPE sxco_package VALUE 'ZLOCAL'.

    DATA xco_on_prem_library         TYPE REF TO zdmo_cl_rap_xco_on_prem_lib.
    DATA xco_lib                     TYPE REF TO zdmo_cl_rap_xco_lib.
    DATA package_name                TYPE sxco_package.
    DATA unique_suffix               TYPE string.
    DATA transport                   TYPE sxco_transport.
    DATA table_name_root             TYPE sxco_dbt_object_name.
    DATA table_name_child            TYPE sxco_dbt_object_name.
    DATA draft_table_name_root       TYPE sxco_dbt_object_name.
    DATA draft_table_name_child      TYPE sxco_dbt_object_name.
    DATA data_generator_class_name   TYPE sxco_ad_object_name.
    DATA calc_travel_elem_class_name TYPE sxco_ad_object_name.
    DATA calc_booking_elem_class_name TYPE sxco_ad_object_name.
    DATA eml_playground_class_name   TYPE sxco_ad_object_name.
    DATA r_view_name_travel          TYPE sxco_cds_object_name.
    DATA r_view_name_booking         TYPE sxco_cds_object_name.
    DATA c_view_name_travel          TYPE sxco_cds_object_name.
    DATA c_view_name_booking         TYPE sxco_cds_object_name.
    DATA i_view_name_travel          TYPE sxco_cds_object_name.
    DATA i_view_name_booking         TYPE sxco_cds_object_name.
    DATA create_mde_files            TYPE abap_bool.
    DATA beh_impl_name_travel        TYPE sxco_ao_object_name.
    DATA beh_impl_name_booking       TYPE sxco_ao_object_name.
    DATA srv_definition_name         TYPE sxco_srvd_object_name.
    DATA srv_binding_o4_name         TYPE sxco_srvb_service_name.
    DATA debug_modus                 TYPE abap_bool VALUE abap_true.

    TYPES: BEGIN OF t_table_fields,
             field                  TYPE sxco_ad_field_name,
             is_key                 TYPE abap_bool,
             not_null               TYPE abap_bool,
             currencyCode           TYPE sxco_cds_field_name,
             unitOfMeasure          TYPE sxco_cds_field_name,
             data_element           TYPE sxco_ad_object_name,
             built_in_type          TYPE cl_xco_ad_built_in_type=>tv_type,
             built_in_type_length   TYPE cl_xco_ad_built_in_type=>tv_length,
             built_in_type_decimals TYPE cl_xco_ad_built_in_type=>tv_decimals,
           END OF t_table_fields.
    TYPES: tt_fields TYPE STANDARD TABLE OF t_table_fields WITH KEY field.

    METHODS create_rap_bo
      IMPORTING out          TYPE REF TO if_oo_adt_classrun_out
      EXPORTING eo_root_node TYPE REF TO zdmo_cl_rap_node.
    METHODS delete_iview_and_mde
      IMPORTING out TYPE REF TO if_oo_adt_classrun_out.
    METHODS create_additional_objects
      IMPORTING out TYPE REF TO if_oo_adt_classrun_out.
    METHODS generate_virt_elem_trav_class
      IMPORTING VALUE(lo_transport) TYPE sxco_transport
                io_put_operation    LIKE mo_put_operation.
    METHODS generate_virt_elem_book_class
      IMPORTING VALUE(lo_transport) TYPE sxco_transport
                io_put_operation    LIKE mo_put_operation.
    METHODS generate_data_generator_class
      IMPORTING VALUE(lo_transport) TYPE sxco_transport
                io_put_operation    LIKE mo_put_operation.
    METHODS generate_eml_playground_class
      IMPORTING VALUE(lo_transport) TYPE sxco_transport
                io_put_operation    LIKE mo_put_operation.
    METHODS generate_cds_mde
      IMPORTING io_out       TYPE REF TO if_oo_adt_classrun_out
                io_root_node TYPE REF TO zdmo_cl_rap_node.
    METHODS get_json_string
      RETURNING VALUE(json_string) TYPE string.
ENDCLASS.


CLASS zdmo_gen_rap110_single_kar IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    xco_on_prem_library = NEW zdmo_cl_rap_xco_on_prem_lib( ).
    IF xco_on_prem_library->on_premise_branch_is_used( ) = abap_true.
      xco_lib = NEW zdmo_cl_rap_xco_on_prem_lib( ).
    ELSE.
      xco_lib = NEW zdmo_cl_rap_xco_cloud_lib( ).
    ENDIF.
  ENDMETHOD.

  METHOD if_oo_adt_classrun~main.

    debug_modus = abap_true.

    "★ 하드코딩 - suffix/package/transport 고정
    transport     = ''.
    unique_suffix = '007'.
    package_name  = 'ZRAP110_007'.

    out->write( | RAP110 exercise generator - fill missing objects | ).
    out->write( | Use transport { transport } / Package { package_name } | ).

    "오브젝트명 세팅
    table_name_root               = 'ZRAP110_ATRAV007'.
    table_name_child              = 'ZRAP110_ABOOK007'.
    draft_table_name_root         = 'ZRAP110_DTRAV007'.
    draft_table_name_child        = 'ZRAP110_DBOOK007'.
    data_generator_class_name     = 'zrap110_data_generator_007'.
    r_view_name_travel            = 'ZRAP110_R_TRAVELTP_007'.
    r_view_name_booking           = 'ZRAP110_R_BOOKINGTP_007'.
    c_view_name_travel            = 'ZRAP110_C_TRAVELTP_007'.
    c_view_name_booking           = 'ZRAP110_C_BOOKINGTP_007'.
    i_view_name_travel            = 'zrap110_I_TravelTP_007'.
    i_view_name_booking           = 'zrap110_I_BookingTP_007'.
    calc_travel_elem_class_name   = 'zrap110_calc_trav_elem_007'.
    calc_booking_elem_class_name  = 'zrap110_calc_book_elem_007'.
    eml_playground_class_name     = 'zrap110_eml_playground_007'.
    create_mde_files              = abap_true.
    beh_impl_name_travel          = 'zrap110_BP_TravelTP_007'.
    beh_impl_name_booking         = 'zrap110_BP_BookingTP_007'.
    srv_definition_name           = 'zrap110_UI_Travel_007'.
    srv_binding_o4_name           = 'zrap110_UI_Travel_O4_007'.

    mo_environment   = get_environment( transport ).
    mo_put_operation = get_put_operation( mo_environment ).

    "★ Abstract Entity / Number Range는 이미 존재 → skip

    "★ RAP BO 생성 (테이블, CDS, BDEF, Service 등)
    create_rap_bo(
      EXPORTING out = out
      IMPORTING eo_root_node = DATA(root_node)
    ).

*    delete_iview_and_mde( out = out ).

    DATA(lo_travel_bdef) = xco_cp_abap_repository=>object->bdef->for(
      CONV #( r_view_name_travel ) ).

    IF lo_travel_bdef->exists( ).
      generate_cds_mde( io_out = out io_root_node = root_node ).
      generate_cds_mde( io_out = out io_root_node = root_node->all_childnodes[ 1 ] ).
      create_additional_objects( out = out ).
    ELSE.
      out->write( | BDEF not found - MDE/additional objects skipped | ).
    ENDIF.

    out->write( | Done. Check package { package_name } | ).

  ENDMETHOD.

  METHOD create_rap_bo.
    DATA(json_string) = get_json_string( ).
    TRY.
        DATA(rap_bo_generator) = zdmo_cl_rap_generator=>create_for_cloud_development( json_string ).
        eo_root_node = rap_bo_generator->root_node.
        DATA(lt_todos) = rap_bo_generator->generate_bo( ).
        IF debug_modus = abap_true.
          out->write( | rap bo generated: { rap_bo_generator->root_node->rap_node_objects-cds_view_r } | ).
          LOOP AT lt_todos INTO DATA(ls_todo).
            out->write( ls_todo-message ).
          ENDLOOP.
        ENDIF.
      CATCH cx_xco_gen_put_exception INTO DATA(bo_gen_exception).
        out->write( cl_message_helper=>get_latest_t100_exception( bo_gen_exception )->if_message~get_longtext( ) ).
        DATA(lt_findings) = bo_gen_exception->findings->get( ).
        LOOP AT lt_findings INTO DATA(finding).
          out->write( finding->message->get_text( ) ).
        ENDLOOP.
      CATCH zdmo_cx_rap_generator INTO DATA(rap_generator_exception).
        out->write( cl_message_helper=>get_latest_t100_exception( rap_generator_exception )->if_message~get_longtext( ) ).
        EXIT.
    ENDTRY.
  ENDMETHOD.

  METHOD delete_iview_and_mde.
    TRY.
        DATA lv_del_transport TYPE sxco_transport.
        lv_del_transport = transport.
        DATA(mo_environment2) = get_environment( lv_del_transport ).

        DATA(lo_delete_ddlx) = mo_environment2->for-ddlx->create_delete_operation( ).
        lo_delete_ddlx->add_object( c_view_name_travel ).
        lo_delete_ddlx->add_object( c_view_name_booking ).
        lo_delete_ddlx->execute( ).
        IF debug_modus = abap_true.
          out->write( |Success: deleting CDS MDE objects| ).
        ENDIF.

        DATA(lo_delete_bdef) = mo_environment2->for-bdef->create_delete_operation( ).
        lo_delete_bdef->add_object( i_view_name_travel ).
        lo_delete_bdef->execute( ).
        IF debug_modus = abap_true.
          out->write( |Success: deleting bdef interface| ).
        ENDIF.

        DATA(lo_delete_ddls) = mo_environment2->for-ddls->create_delete_operation( ).
        lo_delete_ddls->add_object( i_view_name_travel ).
        lo_delete_ddls->add_object( i_view_name_booking ).
        lo_delete_ddls->execute( ).
        IF debug_modus = abap_true.
          out->write( |Success: deleting CDS interface objects| ).
        ENDIF.

      CATCH cx_xco_gen_put_exception INTO DATA(del_exception).
        out->write( cl_message_helper=>get_latest_t100_exception( del_exception )->if_message~get_longtext( ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD create_additional_objects.
    TRY.
        DATA(op2) = get_put_operation( mo_environment ).
        generate_virt_elem_trav_class( io_put_operation = op2 lo_transport = transport ).
        op2->execute( ).
      CATCH cx_xco_gen_put_exception INTO DATA(e2).
        out->write( cl_message_helper=>get_latest_t100_exception( e2 )->if_message~get_longtext( ) ).
    ENDTRY.
    TRY.
        DATA(op3) = get_put_operation( mo_environment ).
        generate_virt_elem_book_class( io_put_operation = op3 lo_transport = transport ).
        op3->execute( ).
      CATCH cx_xco_gen_put_exception INTO DATA(e3).
        out->write( cl_message_helper=>get_latest_t100_exception( e3 )->if_message~get_longtext( ) ).
    ENDTRY.
    TRY.
        DATA(op4) = get_put_operation( mo_environment ).
        generate_data_generator_class( io_put_operation = op4 lo_transport = transport ).
        op4->execute( ).
      CATCH cx_xco_gen_put_exception INTO DATA(e4).
        out->write( cl_message_helper=>get_latest_t100_exception( e4 )->if_message~get_longtext( ) ).
    ENDTRY.
    TRY.
        DATA(op5) = get_put_operation( mo_environment ).
        generate_eml_playground_class( io_put_operation = op5 lo_transport = transport ).
        op5->execute( ).
      CATCH cx_xco_gen_put_exception INTO DATA(e5).
        out->write( cl_message_helper=>get_latest_t100_exception( e5 )->if_message~get_longtext( ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD generate_data_generator_class.
    EXIT.
  ENDMETHOD.

  METHOD generate_virt_elem_trav_class.
    DATA(lo_spec) = io_put_operation->for-clas->add_object( calc_travel_elem_class_name
      )->set_package( package_name )->create_form_specification( ).
    lo_spec->set_short_description( |Calculate Travel Virtual Elements| ).
  ENDMETHOD.

  METHOD generate_virt_elem_book_class.
    DATA(lo_spec) = io_put_operation->for-clas->add_object( calc_booking_elem_class_name
      )->set_package( package_name )->create_form_specification( ).
    lo_spec->set_short_description( |Calculate Booking Virtual Elements| ).
  ENDMETHOD.

  METHOD generate_eml_playground_class.
    DATA(lo_spec) = io_put_operation->for-clas->add_object( eml_playground_class_name
      )->set_package( package_name )->create_form_specification( ).
    lo_spec->set_short_description( | EML Playground Class (007)| ).
    lo_spec->definition->add_interface( 'if_oo_adt_classrun' ).
    lo_spec->implementation->add_method( |if_oo_adt_classrun~main|
        )->set_source( VALUE #(
          ( |DATA travel_keys TYPE TABLE FOR READ IMPORT ZRAP110_R_TravelTP_007.| )
          ( |travel_keys = VALUE #( ( TravelID = 'xxxxx' ) ).| )
          ( |READ ENTITIES OF ZRAP110_R_TravelTP_007| )
          ( |  ENTITY Travel| )
          ( |  FIELDS ( TravelID AgencyID CustomerID BeginDate EndDate )| )
          ( |  WITH travel_keys| )
          ( |  RESULT DATA(lt_travels_read)| )
          ( |  FAILED DATA(failed)| )
          ( |  REPORTED DATA(reported).| )
          ( |out->write( lt_travels_read ).| )
        ) ).
  ENDMETHOD.

  METHOD generate_cds_mde.
    DATA: pos              TYPE i VALUE 0,
          lo_field         TYPE REF TO if_xco_gen_ddlx_s_fo_field,
          lv_del_transport TYPE sxco_transport.

    DATA(io_rap_bo_node) = io_root_node.
    lv_del_transport = transport.

    DATA(mo_env_mde)   = xco_cp_generation=>environment->dev_system( lv_del_transport ).
    DATA(mo_put_mde)   = mo_env_mde->create_put_operation( ).

    DATA(lo_spec) = mo_put_mde->for-ddlx->add_object(
      io_rap_bo_node->rap_node_objects-meta_data_extension
    )->set_package( package_name )->create_form_specification( ).

    lo_spec->set_short_description( |MDE for { io_rap_bo_node->rap_node_objects-alias }|
      )->set_layer( xco_cp_metadata_extension=>layer->customer
      )->set_view( io_rap_bo_node->rap_node_objects-cds_view_p ).

    LOOP AT io_rap_bo_node->lt_fields INTO DATA(ls_field)
      WHERE name <> io_rap_bo_node->field_name-client.
      pos += 10.
      lo_field = lo_spec->add_field( ls_field-cds_view_field ).

      CASE to_upper( ls_field-name ).
        WHEN io_rap_bo_node->field_name-uuid OR
             io_rap_bo_node->field_name-last_changed_by OR
             io_rap_bo_node->field_name-last_changed_at OR
             io_rap_bo_node->field_name-created_at OR
             io_rap_bo_node->field_name-created_by OR
             io_rap_bo_node->field_name-local_instance_last_changed_at OR
             io_rap_bo_node->field_name-parent_uuid OR
             io_rap_bo_node->field_name-root_uuid OR
             'MIME_TYPE' OR 'FILE_NAME'.
          lo_field->add_annotation( 'UI.hidden' )->value->build( )->add_boolean( iv_value = abap_true ).
        WHEN 'CURRENCY_CODE'.
          " do nothing
        WHEN OTHERS.
          IF ls_field-name <> 'CURRENCY_CODE'  AND ls_field-name <> 'DESCRIPTION'
            AND ls_field-name <> 'TOTAL_PRICE'  AND ls_field-name <> 'BOOKING_FEE'
            AND ls_field-name <> 'BEGIN_DATE'   AND ls_field-name <> 'END_DATE'
            AND ls_field-name <> 'ATTACHMENT'.
            DATA(lo_vb) = lo_field->add_annotation( 'UI.lineItem' )->value->build( ).
            DATA(lo_rec) = lo_vb->begin_array( )->begin_record(
              )->add_member( 'position' )->add_number( pos
              )->add_member( 'importance' )->add_enum( 'HIGH' ).
            IF ls_field-is_data_element = abap_false.
              lo_rec->add_member( 'label' )->add_string( CONV #( ls_field-cds_view_field ) ).
            ENDIF.
            lo_vb->end_record( )->end_array( ).
          ENDIF.
          lo_vb = lo_field->add_annotation( 'UI.identification' )->value->build( ).
          lo_rec = lo_vb->begin_array( )->begin_record(
            )->add_member( 'position' )->add_number( pos ).
          IF ls_field-is_data_element = abap_false.
            lo_rec->add_member( 'label' )->add_string( CONV #( ls_field-cds_view_field ) ).
          ENDIF.
          lo_vb->end_record( )->end_array( ).
      ENDCASE.
    ENDLOOP.

    TRY.
        mo_put_mde->execute( ).
      CATCH cx_xco_gen_put_exception INTO DATA(mde_exception).
        io_out->write( cl_message_helper=>get_latest_t100_exception( mde_exception )->if_message~get_longtext( ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD get_json_string.
    json_string =
|\{\r\n| &
|    "namespace":"Z",\r\n| &
|    "package":"ZRAP110_007",\r\n| &
|    "bindingType":"odata_v4_ui",\r\n| &
|    "implementationType":"managed_semantic",\r\n| &
|    "prefix":"RAP110_",\r\n| &
|    "suffix":"_007",\r\n| &
|    "datasourcetype":"table",\r\n| &
|    "draftEnabled":true,\r\n| &
|    "createtable":true,\r\n| &
|    "multiInlineEdit":false,\r\n| &
|    "isCustomizingTable":false,\r\n| &
|    "addBusinessConfigurationRegistration":false,\r\n| &
|    "transportRequest":"",\r\n| &
|    "hierarchy":\r\n| &
|    \{\r\n| &
|    "entityname":"Travel",\r\n| &
|    "dataSource":"ZRAP110_ATRAV007",\r\n| &
|    "objectid":"TRAVEL_ID",\r\n| &
|    "uuid":"",\r\n| &
|    "parentUUID":"",\r\n| &
|    "rootUUID":"",\r\n| &
|    "etagMaster":"LOCAL_LAST_CHANGED_AT",\r\n| &
|    "totalEtag":"LAST_CHANGED_AT",\r\n| &
|    "lastChangedAt":"LAST_CHANGED_AT",\r\n| &
|    "lastChangedBy":"",\r\n| &
|    "localInstanceLastChangedAt":"LOCAL_LAST_CHANGED_AT",\r\n| &
|    "createdAt":"CREATED_AT",\r\n| &
|    "createdBy":"",\r\n| &
|    "draftTable":"ZRAP110_DTRAV007",\r\n| &
|    "cdsRestrictedReuseView":"ZRAP110_R_TRAVELTP_007",\r\n| &
|    "cdsProjectionView":"ZRAP110_C_TRAVELTP_007",\r\n| &
|    "metadataExtensionView":"ZRAP110_C_TRAVELTP_007",\r\n| &
|    "behaviorImplementationClass":"zrap110_BP_TravelTP_007",\r\n| &
|    "serviceDefinition":"zrap110_UI_Travel_007",\r\n| &
|    "serviceBinding":"zrap110_UI_Travel_O4_007",\r\n| &
|    "controlStructure":"",\r\n| &
|    "customQueryImplementationClass":"",\r\n| &
|    "associations":[],\r\n| &
|    "valueHelps":[],\r\n| &
|    "fields":[\r\n| &
|    \{"abapfieldname":"CLIENT","dataelement":"MANDT","isdataelement":true,"iskey":true,"notnull":true\},\r\n| &
|    \{"abapfieldname":"TRAVEL_ID","dataelement":"/dmo/travel_id","isdataelement":true,"iskey":true,"notnull":true,"cdsviewfieldname":"TravelID"\},\r\n| &
|    \{"abapfieldname":"AGENCY_ID","dataelement":"/dmo/agency_id","isdataelement":true,"cdsviewfieldname":"AgencyID"\},\r\n| &
|    \{"abapfieldname":"CUSTOMER_ID","dataelement":"/dmo/customer_id","isdataelement":true,"cdsviewfieldname":"CustomerID"\},\r\n| &
|    \{"abapfieldname":"BEGIN_DATE","dataelement":"/dmo/begin_date","isdataelement":true,"cdsviewfieldname":"BeginDate"\},\r\n| &
|    \{"abapfieldname":"END_DATE","dataelement":"/dmo/end_date","isdataelement":true,"cdsviewfieldname":"EndDate"\},\r\n| &
|    \{"abapfieldname":"BOOKING_FEE","dataelement":"/dmo/booking_fee","isdataelement":true,"currencycode":"CURRENCY_CODE","cdsviewfieldname":"BookingFee"\},\r\n| &
|    \{"abapfieldname":"TOTAL_PRICE","dataelement":"/dmo/total_price","isdataelement":true,"currencycode":"CURRENCY_CODE","cdsviewfieldname":"TotalPrice"\},\r\n| &
|    \{"abapfieldname":"CURRENCY_CODE","dataelement":"/dmo/currency_code","isdataelement":true,"cdsviewfieldname":"CurrencyCode"\},\r\n| &
|    \{"abapfieldname":"DESCRIPTION","dataelement":"/dmo/description","isdataelement":true,"cdsviewfieldname":"Description"\},\r\n| &
|    \{"abapfieldname":"OVERALL_STATUS","dataelement":"/dmo/overall_status","isdataelement":true,"cdsviewfieldname":"OverallStatus"\},\r\n| &
|    \{"abapfieldname":"LAST_CHANGED_AT","dataelement":"ABP_LASTCHANGE_TSTMPL","isdataelement":true,"cdsviewfieldname":"LastChangedAt"\},\r\n| &
|    \{"abapfieldname":"CREATED_BY","dataelement":"abp_creation_user","isdataelement":true,"cdsviewfieldname":"CreatedBy"\},\r\n| &
|    \{"abapfieldname":"CREATED_AT","dataelement":"abp_creation_tstmpl","isdataelement":true,"cdsviewfieldname":"CreatedAt"\},\r\n| &
|    \{"abapfieldname":"LOCAL_LAST_CHANGED_AT","dataelement":"abp_locinst_lastchange_tstmpl","isdataelement":true,"cdsviewfieldname":"LocalLastChangedAt"\}\r\n| &
|    ],\r\n| &
|    "Children":[\r\n| &
|    \{\r\n| &
|    "entityname":"Booking",\r\n| &
|    "dataSource":"ZRAP110_ABOOK007",\r\n| &
|    "objectid":"BOOKING_ID",\r\n| &
|    "uuid":"",\r\n| &
|    "parentUUID":"",\r\n| &
|    "rootUUID":"",\r\n| &
|    "etagMaster":"LOCAL_LAST_CHANGED_AT",\r\n| &
|    "totalEtag":"",\r\n| &
|    "lastChangedAt":"",\r\n| &
|    "lastChangedBy":"",\r\n| &
|    "localInstanceLastChangedAt":"LOCAL_LAST_CHANGED_AT",\r\n| &
|    "createdAt":"",\r\n| &
|    "createdBy":"",\r\n| &
|    "draftTable":"ZRAP110_DBOOK007",\r\n| &
|    "cdsRestrictedReuseView":"ZRAP110_R_BOOKINGTP_007",\r\n| &
|    "cdsProjectionView":"ZRAP110_C_BOOKINGTP_007",\r\n| &
|    "metadataExtensionView":"ZRAP110_C_BOOKINGTP_007",\r\n| &
|    "behaviorImplementationClass":"zrap110_BP_BookingTP_007",\r\n| &
|    "serviceDefinition":"",\r\n| &
|    "serviceBinding":"",\r\n| &
|    "controlStructure":"",\r\n| &
|    "customQueryImplementationClass":"",\r\n| &
|    "associations":[],\r\n| &
|    "valueHelps":[],\r\n| &
|    "fields":[\r\n| &
|    \{"abapfieldname":"CLIENT","dataelement":"MANDT","isdataelement":true,"iskey":true,"notnull":true\},\r\n| &
|    \{"abapfieldname":"TRAVEL_ID","dataelement":"/dmo/travel_id","isdataelement":true,"iskey":true,"notnull":true,"cdsviewfieldname":"TravelID"\},\r\n| &
|    \{"abapfieldname":"BOOKING_ID","dataelement":"/dmo/booking_id","isdataelement":true,"iskey":true,"notnull":true,"cdsviewfieldname":"BookingID"\},\r\n| &
|    \{"abapfieldname":"BOOKING_DATE","dataelement":"/dmo/booking_date","isdataelement":true,"cdsviewfieldname":"BookingDate"\},\r\n| &
|    \{"abapfieldname":"CUSTOMER_ID","dataelement":"/dmo/customer_id","isdataelement":true,"cdsviewfieldname":"CustomerID"\},\r\n| &
|    \{"abapfieldname":"CARRIER_ID","dataelement":"/dmo/carrier_id","isdataelement":true,"cdsviewfieldname":"CarrierID"\},\r\n| &
|    \{"abapfieldname":"CONNECTION_ID","dataelement":"/dmo/connection_id","isdataelement":true,"cdsviewfieldname":"ConnectionID"\},\r\n| &
|    \{"abapfieldname":"FLIGHT_DATE","dataelement":"/dmo/flight_date","isdataelement":true,"cdsviewfieldname":"FlightDate"\},\r\n| &
|    \{"abapfieldname":"BOOKING_STATUS","dataelement":"/dmo/booking_status","isdataelement":true,"cdsviewfieldname":"BookingStatus"\},\r\n| &
|    \{"abapfieldname":"FLIGHT_PRICE","dataelement":"/dmo/flight_price","isdataelement":true,"currencycode":"CURRENCY_CODE","cdsviewfieldname":"FlightPrice"\},\r\n| &
|    \{"abapfieldname":"CURRENCY_CODE","dataelement":"/dmo/currency_code","isdataelement":true,"cdsviewfieldname":"CurrencyCode"\},\r\n| &
|    \{"abapfieldname":"LOCAL_LAST_CHANGED_AT","dataelement":"abp_locinst_lastchange_tstmpl","isdataelement":true,"cdsviewfieldname":"LocalLastChangedAt"\}\r\n| &
|    ]\r\n| &
|    \}\r\n| &
|    ]\r\n| &
|    \}\r\n| &
|\}|.
  ENDMETHOD.

ENDCLASS.

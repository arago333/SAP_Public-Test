@EndUserText.label: 'SD IS API Log Query - Custom Entity'
@ObjectModel.query.implementedBy: 'ABAP:ZBPR_SD_IS_LOG_KAR2'

@UI.headerInfo:
  { typeName: 'IS Log',
    typeNamePlural: 'IS Logs' }

define root custom entity ZR_SD_IS_LOG_KAR2
{
      @UI.hidden    : true
  key MessageGuid   : abap.char(100);

      @UI.hidden    : true
      CriticalityIs : abap.int1;

      @UI.lineItem  : [{ position: 10, criticality: 'CriticalityIs', criticalityRepresentation: #ONLY_ICON }]
      @UI.selectionField: [{ position: 10 }]
      StatusIs      : abap.char(1);

      @UI.hidden    : true
      CriticalityIn : abap.int1;

      @UI.lineItem  : [{ position: 20, criticality: 'CriticalityIn', criticalityRepresentation: #ONLY_ICON }]
      @UI.selectionField: [{ position: 20 }]
      StatusIn      : abap.char(1);

      @UI.lineItem  : [{ position: 30 }]
      FlowName      : abap.char(40);

      @UI.lineItem  : [{ position: 40 }]
      LastTime      : abap.char(20);

      @UI.lineItem  : [{ position: 50 }]
      @Consumption.semanticObject: 'SDISLOG'
      InLogLink     : abap.char(20);

      @UI.hidden    : true
      InLog         : abap.string(0);

      @UI.selectionField: [{ position: 30 }]
      FlowModule    : abap.char(3);

      @UI.selectionField: [{ position: 40 }]
      @Semantics.calendar.dayOfMonth: true
      FlowDate      : abap.dats;

      @UI.selectionField: [{ position: 50 }]
      FlowTime      : abap.tims;

}

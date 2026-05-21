@EndUserText.label: 'SD IS Log - Fetch Log Result'
define abstract entity ZI_SD_IS_LOG_RESULT_KAR
{
  @EndUserText.label: 'Message GUID'
  MessageGuid : abap.char(100);

  @EndUserText.label: 'Log Summary'
  InLogMsg    : abap.char(255);

  @UI.multiLineText: true
  @EndUserText.label: 'Log Detail'
  InLog       : abap.string(0);
}

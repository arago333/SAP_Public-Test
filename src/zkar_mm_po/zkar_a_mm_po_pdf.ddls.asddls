@EndUserText.label: 'PO PDF Action Result'
define abstract entity ZKAR_A_MM_PO_PDF
{
  PdfContent : abap.rawstring(0);
  MimeType   : abap.char(100);
  FileName   : abap.char(255);
}

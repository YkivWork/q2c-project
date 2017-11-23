%dw 1.0
%output application/java
%function asDate(field) field as :date when field != null otherwise null
---
payload map {
  ($ mapObject {
    (EndDate: asDate($)) when ($$ as :string == 'ENDDATE'),
    (StartDate: asDate($)) when ($$ as :string == 'STARTDATE'),
    (($$):$) when ($$ as :string !='ENDDATE') and ($$ as :string !='STARTDATE')
  })
}
%dw 1.0
%output application/json
---
(flowVars.ariaResponse.entitlements default '' splitBy ";") map {
  enabled: true,
  entitlementCode: trim $
}
 
 

        
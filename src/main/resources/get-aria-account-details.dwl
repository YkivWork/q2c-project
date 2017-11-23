%dw 1.0
%output application/xml
%namespace soap http://schemas.xmlsoap.org/soap/envelope/
---
{
  soap#Envelope: {
    soap#Header: {},
    soap#Body: {
      get_acct_details_all_m @(xmlns: p('aria.namespace')): {
        client_no: p('aria.client_no'),
        auth_key: p('aria.auth_key'),

        acct_no: flowVars.ariaValues.ariaAcct,

        include_master_plans: 1,
        include_supp_plans: 1,
        include_billing_groups: 1
      }
    }
  }
}

%dw 1.0
%output application/xml
%namespace aria urn:client:api:wsdl:document/literal_wrapped:vers:11.0:aria_complete_m_api
%namespace soap http://schemas.xmlsoap.org/soap/envelope/
%function statusCode (value) 1 when value == "Active" otherwise -3 when value == "Closed" otherwise -99
// Bug fix 07/20/17
---
{
  soap#Envelope: {
    soap#Header: {},
    soap#Body: {
      aria#update_acct_plan_status_m: {
        client_no: p('aria.client_no'),
        auth_key: p('aria.auth_key'),
        acct_no: flowVars.ariaValues.ariaAcct,

        client_plan_instance_id: flowVars.ariaValues.ariaMPI,
        status_cd: statusCode(flowVars.theProject.projectStatus),
        force_bill_date_reset: 1
      }
    }
  }
}
